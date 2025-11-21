SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: ispGetStocktakeParm2                                    */
/* Creation Date: 23-NOV-2016                                           */
/* Copyright: LF Logistics                                              */
/* Written by: YTWan                                                    */
/*                                                                      */
/* Purpose: WMS-648 - GW StockTake Parameter2 Enhancement               */
/*        :                                                             */
/* Called By: ispGenCountSheet                                          */
/*          : ispGenCountSheetByUCC                                     */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver Purposes                                  */
/************************************************************************/
CREATE PROC [dbo].[ispGetStocktakeParm2]
           @c_Stocktakekey             NVARCHAR(30)
         , @c_EmptyLocation            NVARCHAR(10)   = 'N'  -- Same as Blank Count Sheet
         , @c_ByPalletLevel            NVARCHAR(10)   = 'N'
         , @c_SkuConditionSQL          NVARCHAR(MAX)   
         , @c_LocConditionSQL          NVARCHAR(MAX)    
         , @c_ExtendedConditionSQL1    NVARCHAR(MAX)   
         , @c_ExtendedConditionSQL2    NVARCHAR(MAX)   
         , @c_ExtendedConditionSQL3    NVARCHAR(MAX)   
         , @c_StocktakeParm2SQL        NVARCHAR(MAX)   OUTPUT   
         , @c_StocktakeParm2OtherSQL   NVARCHAR(MAX)   OUTPUT   
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt       INT
         , @n_RecCnt          INT
         , @n_Cnt             INT
         , @c_Cnt             NVARCHAR(2)
         , @c_LBLVal          NVARCHAR(30) 
         , @c_LBLCol          NVARCHAR(30)
         , @c_ValCol          NVARCHAR(30) 
         , @c_Label           NVARCHAR(30)
         , @c_Label01         NVARCHAR(30)
         , @c_Label02         NVARCHAR(30)
         , @c_Label03         NVARCHAR(30)
         , @c_Label04         NVARCHAR(30)
         , @c_Label05         NVARCHAR(30)
         , @c_TableCol        NVARCHAR(30)
         , @c_FromTableKey    NVARCHAR(100)
         , @c_TableKeys       NVARCHAR(100)

         , @c_FromTable       NVARCHAR(30)
         , @c_ParmTables      NVARCHAR(30)

         , @c_SQL             NVARCHAR(4000)

         , @b_debug           INT

   SET @n_StartTCnt = @@TRANCOUNT

   SET @c_ExtendedConditionSQL1 = REPLACE(@c_ExtendedConditionSQL1, '( ', '(')
   SET @c_ExtendedConditionSQL2 = REPLACE(@c_ExtendedConditionSQL2, '( ', '(')
   SET @c_ExtendedConditionSQL3 = REPLACE(@c_ExtendedConditionSQL3, '( ', '(')
   SET @c_StocktakeParm2SQL = ''
   SET @c_StocktakeParm2OtherSQL = ''
   SET @c_ParmTables = 'SKU,LOC,LOTATTRIBUTE'
   SET @c_TableKeys    = 'SKU.SKU,LOC.LOC'

   SET @n_RecCnt    = 0
   SELECT TOP 1 
          @n_RecCnt   = 1
         ,@c_Label   = ISNULL(RTRIM(TableName),'')
         ,@c_Label01 = ISNULL(RTRIM(Label01),'')
         ,@c_Label02 = ISNULL(RTRIM(Label02),'')
         ,@c_Label03 = ISNULL(RTRIM(Label03),'')
         ,@c_Label04 = ISNULL(RTRIM(Label04),'')
         ,@c_Label05 = ISNULL(RTRIM(Label05),'')
   FROM   STOCKTAKEPARM2 WITH (NOLOCK)
   WHERE  Stocktakekey = @c_StockTakekey

   IF @n_RecCnt = 0
   BEGIN
      GOTO QUIT_SP
   END

   SET @n_Cnt = 0
   WHILE @n_Cnt <= 5
   BEGIN
      SET @c_Cnt = CASE WHEN @n_Cnt = 0 THEN '' ELSE '0' + RTRIM(CONVERT(VARCHAR(1), @n_Cnt)) END
      SET @c_LBLCol = CASE WHEN @n_Cnt = 0 THEN 'TableName' ELSE 'Label' + @c_Cnt END
      SET @c_ValCol = CASE WHEN @n_Cnt = 0 THEN 'Value' ELSE 'Value' + @c_Cnt END
      
      SET @c_SQL = N'SET @c_LBLVal = @c_Label' + @c_Cnt  
      
      EXECUTE sp_ExecuteSQL @c_SQL
                        ,N' @c_LBLVal    NVARCHAR(30)   OUTPUT
                          , @c_Label     NVARCHAR(30)
                          , @c_Label01   NVARCHAR(30)
                          , @c_Label02   NVARCHAR(30)
                          , @c_Label03   NVARCHAR(30)
                          , @c_Label04   NVARCHAR(30)
                          , @c_Label05   NVARCHAR(30)' 
                        , @c_LBLVal       OUTPUT
                        , @c_Label 
                        , @c_Label01
                        , @c_Label02
                        , @c_Label03
                        , @c_Label04
                        , @c_Label05

      SET @c_LBLVal = RTRIM(@c_LBLVal)
      SET @c_ValCol = RTRIM(@c_ValCol)

      IF @c_LBLVal <> ''
      BEGIN
         --IF @c_EmptyLocation = 'Y' AND @c_LBLVal <> 'LOC'
         --BEGIN
         --   GOTO NEXT_LABEL
         --END 

         SET @n_RecCnt = 0
         SELECT TOP 1
                @n_RecCnt = 1
               ,@c_TableCol = RTRIM(SysCol.Table_Name) + '.' + RTRIM(SysCol.Column_Name)
         FROM  INFORMATION_SCHEMA.COLUMNS SysCol 
         JOIN  dbo.fnc_DelimSplit(',', @c_ParmTables) TC ON (SysCol.Table_Name = TC.ColValue)
         WHERE SysCol.Table_Schema = 'dbo' 
         --AND   SysCol.Table_Name   IN ('SKU', 'LOC', 'LOTATTRIBUTE')
         AND   SysCol.Column_Name  = @c_LBLVal 
         ORDER BY SysCol.Table_Name DESC

         IF @n_RecCnt > 0 
         BEGIN
            --IF @c_ByPalletLevel = 'Y' AND CHARINDEX('SKU.', @c_TableCol) > 0
            --BEGIN
            --   GOTO NEXT_LABEL
            --END

            IF @c_StocktakeParm2SQL = ''
            BEGIN
               SET @c_StocktakeParm2SQL = 'JOIN STOCKTAKEPARM2 PARM2 WITH (NOLOCK) ON (PARM2.StockTakeKey = ''' +@c_StockTakeKey+ ''') '
            END

            SET @c_StocktakeParm2SQL = @c_StocktakeParm2SQL + 'AND (PARM2.' + @c_LBLCol + ' = ''' + @c_LBLVal + ''') '
            SET @c_StocktakeParm2SQL = @c_StocktakeParm2SQL + 'AND (' + @c_TableCol + ' = PARM2.' + @c_ValCol + ') '
         END
      END

      NEXT_LABEL:
      SET @n_Cnt = @n_Cnt + 1   
   END -- WHILE @n_Cnt <= 5

   IF CHARINDEX('SKU.', @c_StocktakeParm2SQL) > 0  
   BEGIN
      SET @c_ParmTables = REPLACE(@c_ParmTables, 'SKU', '')
      SET @c_ParmTables = REPLACE(@c_ParmTables, ',LOTATTRIBUTE', '')
   END 

   IF CHARINDEX('LOC.', @c_StocktakeParm2SQL) > 0  
   BEGIN
      SET @c_ParmTables = REPLACE(@c_ParmTables, ',LOC', '')
   END 

   IF CHARINDEX('LOTATTRIBUTE.', @c_StocktakeParm2SQL) > 0  
   BEGIN
      SET @c_ParmTables = REPLACE(@c_ParmTables, ',LOTATTRIBUTE', '')
   END 
   
   IF @c_EmptyLocation = 'Y' AND @c_ParmTables <> ''  -- Only Return Parms SQL or Join StocktakeParm2 data from LOC tables
   BEGIN   
      IF CHARINDEX('SKU', @c_StocktakeParm2SQL) > 0 OR CHARINDEX('LOTATTRIBUTE', @c_StocktakeParm2SQL) > 0 -- BY LOC
      BEGIN
         SET @c_StocktakeParm2SQL = ''
      END 

      IF CHARINDEX('SKU', @c_ParmTables) > 0   
      BEGIN
         SET @c_ParmTables = REPLACE(@c_ParmTables, 'SKU', '')
      END

      IF CHARINDEX('LOTATTRIBUTE', @c_ParmTables) > 0   
      BEGIN
         SET @c_ParmTables = REPLACE(@c_ParmTables, ',LOTATTRIBUTE', '') 
      END
   END

   IF @c_ByPalletLevel = 'Y' AND @c_ParmTables <> ''  -- Does not return parms sql if stocktakeparms data from SKU, LA Or SKU And LA
   BEGIN   
      IF CHARINDEX('SKU', @c_StocktakeParm2SQL) > 0 OR CHARINDEX('LOTATTRIBUTE', @c_StocktakeParm2SQL) > 0 -- BY LOC
      BEGIN
         SET @c_ParmTables = REPLACE(@c_ParmTables, ',LOC', '')
      END 
   END

   IF CHARINDEX('SKU.', @c_StocktakeParm2SQL) > 0 OR CHARINDEX('LOTATTRIBUTE.', @c_StocktakeParm2SQL) > 0 
   BEGIN
      SET @c_StocktakeParm2SQL = @c_StocktakeParm2SQL + 'AND (PARM2.Storerkey = SKU.Storerkey)'
   END

   IF @c_ParmTables = ''
   BEGIN
      GOTO QUIT_SP
   END
 
   DECLARE CUR_EXTPARM CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT RTRIM(ColValue) + '.'
   FROM   dbo.fnc_DelimSplit(',', @c_ParmTables)
   ORDER BY SeqNo
   
   OPEN CUR_EXTPARM
   
   FETCH NEXT FROM CUR_EXTPARM INTO @c_FromTable
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      IF CHARINDEX(@c_FromTable, @c_StocktakeParm2SQL) <= 0  
      BEGIN
         IF CHARINDEX(@c_FromTable, @c_LocConditionSQL) > 0
         BEGIN
            SET @c_StocktakeParm2OtherSQL = @c_LocConditionSQL
         END
   
         IF CHARINDEX(@c_FromTable, @c_SkuConditionSQL) > 0
         BEGIN
            SET @c_StocktakeParm2OtherSQL = @c_SkuConditionSQL
         END

         IF CHARINDEX(@c_FromTable, @c_ExtendedConditionSQL1) > 0  
         BEGIN
            SET @c_StocktakeParm2OtherSQL = @c_StocktakeParm2OtherSQL + ' ' + @c_ExtendedConditionSQL1
         END

         IF CHARINDEX(@c_FromTable, @c_ExtendedConditionSQL2) > 0  
         BEGIN
            SET @c_StocktakeParm2OtherSQL = @c_StocktakeParm2OtherSQL + ' ' + @c_ExtendedConditionSQL2
         END

         IF CHARINDEX(@c_FromTable, @c_ExtendedConditionSQL3) > 0  
         BEGIN
            SET @c_StocktakeParm2OtherSQL = @c_StocktakeParm2OtherSQL + ' ' + @c_ExtendedConditionSQL3
         END
      END
      FETCH NEXT FROM CUR_EXTPARM INTO @c_FromTable
   END
   CLOSE CUR_EXTPARM
   DEALLOCATE CUR_EXTPARM 
QUIT_SP: 
   SET @b_debug = 0
   IF @b_debug = 1
   BEGIN
      select @c_StocktakeParm2OtherSQL  '@c_StocktakeParm2OtherSQL'
      select @c_StocktakeParm2SQL   '@c_StocktakeParm2SQL'
      select @c_EmptyLocation '@c_EmptyLocation'
      select @c_ByPalletLevel '@c_ByPalletLevel'
   END
END -- procedure

GO