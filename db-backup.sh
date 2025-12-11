#!/bin/bash
# Database Backup and Restore Script for DhakaCart
# Supports PostgreSQL/MySQL in RDS
# Usage: ./db-backup.sh [backup|restore|list-backups]

set -e

DB_INSTANCE_ID="${DB_INSTANCE_ID:-dhakacart-db}"
AWS_REGION="${AWS_REGION:-ap-southeast-1}"
S3_BUCKET="${S3_BUCKET:-dhakacart-backups}"
BACKUP_DIR="./backups"

mkdir -p "$BACKUP_DIR"

echo "=================================================="
echo "🗄️  DhakaCart Database Management"
echo "=================================================="
echo ""

# Function to create backup
backup_database() {
    echo "📦 Creating database backup..."
    
    # Create RDS snapshot
    SNAPSHOT_ID="dhakacart-backup-$(date +%Y%m%d-%H%M%S)"
    
    echo "Creating snapshot: $SNAPSHOT_ID"
    aws rds create-db-snapshot \
        --db-instance-identifier "$DB_INSTANCE_ID" \
        --db-snapshot-identifier "$SNAPSHOT_ID" \
        --region "$AWS_REGION"
    
    echo "⏳ Waiting for snapshot to complete..."
    aws rds wait db-snapshot-available \
        --db-snapshot-identifier "$SNAPSHOT_ID" \
        --region "$AWS_REGION"
    
    echo "✅ Snapshot created successfully: $SNAPSHOT_ID"
    
    # Optionally export to S3
    if [ ! -z "$S3_BUCKET" ]; then
        echo ""
        echo "📤 Exporting snapshot to S3..."
        EXPORT_ID="dhakacart-export-$(date +%Y%m%d-%H%M%S)"
        
        aws rds start-export-task \
            --export-task-identifier "$EXPORT_ID" \
            --source-arn "arn:aws:rds:${AWS_REGION}:$(aws sts get-caller-identity --query Account --output text):snapshot:${SNAPSHOT_ID}" \
            --s3-bucket-name "$S3_BUCKET" \
            --s3-prefix "exports/" \
            --iam-role-arn "arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):role/rds-export-role" \
            --region "$AWS_REGION"
        
        echo "✅ Export task initiated: $EXPORT_ID"
    fi
}

# Function to list backups
list_backups() {
    echo "📋 Available Database Snapshots:"
    echo ""
    
    aws rds describe-db-snapshots \
        --db-instance-identifier "$DB_INSTANCE_ID" \
        --region "$AWS_REGION" \
        --query 'DBSnapshots[*].[DBSnapshotIdentifier,SnapshotCreateTime,Status]' \
        --output table
    
    echo ""
    echo "📋 Available S3 Backups:"
    echo ""
    
    aws s3 ls "s3://${S3_BUCKET}/exports/" \
        --region "$AWS_REGION" \
        --recursive || echo "No S3 exports found or bucket doesn't exist"
}

# Function to restore from backup
restore_database() {
    local snapshot_id="$1"
    local new_instance_id="${2:-dhakacart-db-restored}"
    
    if [ -z "$snapshot_id" ]; then
        echo "❌ Please provide snapshot ID"
        echo "Usage: $0 restore <snapshot-id> [new-instance-id]"
        exit 1
    fi
    
    echo "🔄 Restoring database from snapshot: $snapshot_id"
    echo "📍 New instance ID: $new_instance_id"
    
    aws rds restore-db-instance-from-db-snapshot \
        --db-instance-identifier "$new_instance_id" \
        --db-snapshot-identifier "$snapshot_id" \
        --region "$AWS_REGION"
    
    echo "⏳ Waiting for restoration to complete..."
    aws rds wait db-instance-available \
        --db-instance-identifier "$new_instance_id" \
        --region "$AWS_REGION"
    
    echo "✅ Database restored successfully: $new_instance_id"
    
    # Get connection details
    ENDPOINT=$(aws rds describe-db-instances \
        --db-instance-identifier "$new_instance_id" \
        --region "$AWS_REGION" \
        --query 'DBInstances[0].Endpoint.Address' \
        --output text)
    
    echo ""
    echo "📌 Connection Details:"
    echo "Endpoint: $ENDPOINT"
    echo "Port: 5432 (PostgreSQL) or 3306 (MySQL)"
}

# Function to perform point-in-time recovery
point_in_time_restore() {
    local restore_time="$1"
    local new_instance_id="${2:-dhakacart-db-pitr}"
    
    if [ -z "$restore_time" ]; then
        echo "❌ Please provide restore time (e.g., 2025-12-11T10:30:00Z)"
        exit 1
    fi
    
    echo "🔄 Performing Point-In-Time Recovery..."
    echo "📍 Restore Time: $restore_time"
    echo "📍 New Instance: $new_instance_id"
    
    aws rds restore-db-instance-to-point-in-time \
        --source-db-instance-identifier "$DB_INSTANCE_ID" \
        --target-db-instance-identifier "$new_instance_id" \
        --restore-time "$restore_time" \
        --region "$AWS_REGION"
    
    echo "⏳ Waiting for restoration to complete..."
    aws rds wait db-instance-available \
        --db-instance-identifier "$new_instance_id" \
        --region "$AWS_REGION"
    
    echo "✅ Point-in-time recovery completed: $new_instance_id"
}

# Function to enable automated backups
enable_automated_backups() {
    echo "🔧 Enabling automated backups..."
    
    aws rds modify-db-instance \
        --db-instance-identifier "$DB_INSTANCE_ID" \
        --backup-retention-period 7 \
        --preferred-backup-window "03:00-04:00" \
        --apply-immediately \
        --region "$AWS_REGION"
    
    echo "✅ Automated backups enabled (7-day retention)"
    echo "   Backup window: 03:00-04:00 UTC"
}

# Function to delete backup
delete_backup() {
    local snapshot_id="$1"
    
    if [ -z "$snapshot_id" ]; then
        echo "❌ Please provide snapshot ID"
        exit 1
    fi
    
    echo "⚠️  WARNING: This will permanently delete snapshot: $snapshot_id"
    read -p "Continue? (yes/no): " -r
    
    if [[ $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        aws rds delete-db-snapshot \
            --db-snapshot-identifier "$snapshot_id" \
            --region "$AWS_REGION"
        echo "✅ Snapshot deleted: $snapshot_id"
    else
        echo "❌ Deletion cancelled"
    fi
}

# Main logic
case "${1:-help}" in
    backup)
        backup_database
        ;;
    restore)
        restore_database "$2" "$3"
        ;;
    list-backups|list)
        list_backups
        ;;
    pitr)
        point_in_time_restore "$2" "$3"
        ;;
    enable-backups)
        enable_automated_backups
        ;;
    delete-backup)
        delete_backup "$2"
        ;;
    *)
        echo "Usage: $0 {backup|restore|list-backups|pitr|enable-backups|delete-backup}"
        echo ""
        echo "Examples:"
        echo "  $0 backup                           # Create database snapshot"
        echo "  $0 list-backups                     # List all available backups"
        echo "  $0 restore snapshot-id new-db      # Restore from snapshot"
        echo "  $0 pitr '2025-12-11T10:30:00Z'     # Point-in-time recovery"
        echo "  $0 enable-backups                   # Enable automated backups"
        echo "  $0 delete-backup snapshot-id       # Delete backup"
        echo ""
        exit 1
        ;;
esac
