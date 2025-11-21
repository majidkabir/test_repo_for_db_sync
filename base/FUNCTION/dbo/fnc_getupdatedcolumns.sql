SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Function       : fnc_GetUpdatedColumns                               */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Purpose: To return records with updated columns in trigger           */
/*                                                                      */
/* Usage: Must Call from Trigger                                        */
/*   DECLARE @ColumnsUpdated VARBINARY(1000)                            */
/*   SET @ColumnsUpdated = COLUMNS_UPDATED()                            */
/*   SELECT * FROM dbo.fnc_GetUpdatedColumns('<TableName>',             */
/*                                           @ColumnsUpdated)           */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Rev  Author     Purposes                                */
/* 2014-Aug-07  1.0  SHONG    Created                                   */
/************************************************************************/
CREATE FUNCTION [dbo].[fnc_GetUpdatedColumns]( 
@Tablename VARCHAR(100), @ColumnsUpdated VARBINARY(255) ) 
RETURNS TABLE 
AS 
RETURN 
    SELECT 
        COLUMN_NAME 
    FROM INFORMATION_SCHEMA.COLUMNS Field 
    WHERE 
        TABLE_NAME = @Tablename 
        AND sys.fn_IsBitSetInBitmask( @ColumnsUpdated,
            COLUMNPROPERTY(OBJECT_ID(TABLE_SCHEMA + '.' + TABLE_NAME), 
            COLUMN_NAME, 'ColumnID')) <> 0
            

GO