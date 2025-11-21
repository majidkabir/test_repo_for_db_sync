CREATE TABLE [dbo].[orderselectioncondition]
(
    [OrderSelectionKey] nvarchar(10) NOT NULL,
    [OrderSelectionLineNumber] nvarchar(5) NOT NULL,
    [Description] nvarchar(250) NULL,
    [Type] nvarchar(10) NULL,
    [ConditionGroup] nvarchar(10) NULL,
    [OperatorAndOr] nvarchar(10) NULL,
    [FieldName] nvarchar(50) NULL,
    [Operator] nvarchar(10) NULL,
    [Value] nvarchar(4000) NULL,
    CONSTRAINT [PK_OrderSelectionCondition] PRIMARY KEY ([OrderSelectionKey], [OrderSelectionLineNumber])
);
GO
