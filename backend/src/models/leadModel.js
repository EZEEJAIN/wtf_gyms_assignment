module.exports = (sequelize, DataTypes) => {
    const LeadMaster = sequelize.define('lead_master', {
        id: {
            type: DataTypes.UUID,
            primaryKey: true,
        },
        full_name: {
            type: DataTypes.STRING(100),
            allowNull: true,
            required: true
        },
        phone: {
            type: DataTypes.STRING(20),
            unique: true,
            allowNull: true,
            required: true
        },
        email: {
            type: DataTypes.STRING(100),
            allowNull: true,
            required: true
        },
        source: {
            type: DataTypes.STRING(50),
            allowNull: false,
            required: true,
            check: {
                isIn: [["Website", "Referral", "Social Media", "Email Campaign", "Other"]]
            }
        },
        status: {
            type: DataTypes.STRING(50),
            allowNull: true,
            required: true,
            check: {
                isIn: [['New', 'Contacted', 'Visit Scheduled', "Closed", 'Lost']]
            }
        },
        assigned_to: {
            type: DataTypes.STRING(100),
            allowNull: true,
            required: true
        },
        created_at: {
            type: DataTypes.DATE,
            allowNull: false,
            defaultValue: DataTypes.NOW,
        },
    }, {
        tableName: 'lead_master',
        timestamps: false,
    });

    return LeadMaster;
};

