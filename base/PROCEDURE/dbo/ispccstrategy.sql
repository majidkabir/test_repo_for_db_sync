SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Trigger: ispCCStrategy                                               */
/* Creation Date: 28-JUN-2016                                           */
/* Copyright: LF Logistics                                              */
/* Written by: YTWan                                                    */
/*                                                                      */
/* Purpose: SOS#370874 - TW Add Cycle Count Strategy                    */
/*        :                                                             */
/* Called By: ispCheckOutstandingOrders                                 */
/*          : ispCheckUCCbal                                            */
/*          : ispCountVsSystemVsAdjReport                               */
/*          : ispGenBlankSheet                                          */
/*          : ispGenCCAdjustmentPost_MultiCnt                           */
/*          : ispGenCCPosting                                           */
/*          : ispGenCCPostMultipleCnt                                   */
/*          : ispGenCountSheet                                          */
/*          : ispGenCountSheetByUCC                                     */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver Purposes                                  */
/************************************************************************/
CREATE PROC [dbo].[ispCCStrategy] 
            @c_StockTakeKey      NVARCHAR(10)
         ,  @c_StrategySQL       NVARCHAR(4000) OUTPUT
         ,  @c_StrategySkuSQL    NVARCHAR(4000) OUTPUT
         ,  @c_StrategyLocSQL    NVARCHAR(4000) OUTPUT
         ,  @b_Success           INT = 0  OUTPUT 
         ,  @n_err               INT = 0  OUTPUT 
         ,  @c_errmsg            NVARCHAR(215) = '' OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt       INT
         , @n_Continue        INT 
         
         , @n_idx             INT
         , @n_Cnt             INT
         , @c_Cnt             NVARCHAR(2)
         , @c_CCStrategykey   NVARCHAR(30)
         , @c_SPName          NVARCHAR(255)
         , @c_ParmField       NVARCHAR(30)
         , @c_ParmField01     NVARCHAR(30)
         , @c_ParmField02     NVARCHAR(30)
         , @c_ParmField03     NVARCHAR(30)
         , @c_ParmField04     NVARCHAR(30)
         , @c_ParmField05     NVARCHAR(30)
         , @c_ParmField06     NVARCHAR(30)
         , @c_ParmField07     NVARCHAR(30)
         , @c_ParmField08     NVARCHAR(30)
         , @c_Notes           NVARCHAR(4000)

         , @c_Parameter       NVARCHAR(125)
         , @c_Parameter01     NVARCHAR(125)
         , @c_Parameter02     NVARCHAR(125)
         , @c_Parameter03     NVARCHAR(125)
         , @c_Parameter04     NVARCHAR(125)
         , @c_Parameter05     NVARCHAR(125)
         , @c_Parameter06     NVARCHAR(125)
         , @c_Parameter07     NVARCHAR(125)
         , @c_Parameter08     NVARCHAR(125)

         , @c_SQL             NVARCHAR(4000)
         , @c_SQLGROUPBY      NVARCHAR(4000)
         , @c_SQLORDERBY      NVARCHAR(4000)
         , @c_ParmsSQL        NVARCHAR(4000)
         , @c_ParmsSQL1       NVARCHAR(4000)
         , @c_ParmsSQL2       NVARCHAR(4000)

         , @c_TableName       NVARCHAR(30)
   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1
   SET @n_err      = 0
   SET @c_errmsg   = ''

   BEGIN TRAN

   SET @c_CCStrategykey = ''
   SET @c_Parameter01 = ''
   SET @c_Parameter02 = ''
   SET @c_Parameter03 = ''
   SET @c_Parameter04 = ''
   SET @c_Parameter05 = ''
   SET @c_ParmField06 = ''
   SET @c_Parameter06 = ''
   SET @c_ParmField07 = ''
   SET @c_Parameter07 = ''
   SET @c_ParmField08 = ''
   SET @c_Parameter08 = ''

   SELECT @c_CCStrategykey = ISNULL(RTRIM(StrategyKey),'')
         ,@c_Parameter01 = ISNULL(RTRIM(Parameter01),'')
         ,@c_Parameter02 = ISNULL(RTRIM(Parameter02),'')
         ,@c_Parameter03 = ISNULL(RTRIM(Parameter03),'')
         ,@c_Parameter04 = ISNULL(RTRIM(Parameter04),'')
         ,@c_Parameter05 = ISNULL(RTRIM(Parameter05),'')
         ,@c_ParmField06 = 'LOC.Facility'
         ,@c_Parameter06 = ISNULL(RTRIM(Facility),'')
         ,@c_ParmField07 = 'STORER.Storerkey'
         ,@c_Parameter07 = ISNULL(RTRIM(StorerKey),'')
         ,@c_ParmField08 = 'LOC.PutawayZone'
         ,@c_Parameter08 = ISNULL(RTRIM(ZoneParm),'')
   FROM STOCKTAKESHEETPARAMETERS WITH (NOLOCK)
   WHERE StockTakeKey = @c_StockTakeKey

   IF @c_CCStrategykey = ''
   BEGIN
      GOTO QUIT_SP
   END
      
   SET @n_Cnt    = 0
   SET @c_SPName = ''
   SET @c_ParmField01  = ''
   SET @c_ParmField02  = ''
   SET @c_ParmField03  = ''
   SET @c_ParmField04  = ''
   SET @c_ParmField05  = ''
   SET @c_Notes  = ''

   SELECT @n_Cnt    = 1
         ,@c_SPName = ISNULL(RTRIM(Long),'')
         ,@c_ParmField01  = ISNULL(RTRIM(UDF01),'')
         ,@c_ParmField02  = ISNULL(RTRIM(UDF02),'')
         ,@c_ParmField03  = ISNULL(RTRIM(UDF03),'')
         ,@c_ParmField04  = ISNULL(RTRIM(UDF04),'')
         ,@c_ParmField05  = ISNULL(RTRIM(UDF05),'') 
         ,@c_Notes  = ISNULL(RTRIM(Notes),'')
         --,@c Notes2 = ISNULL(RTRIM(Notes2),'')                                    
   FROM   CODELKUP WITH (NOLOCK)
   WHERE  ListName = 'CCSTRATEGY'
   AND    Code = @c_CCStrategykey
   ORDER BY Code

   IF @n_Cnt = 0 
   BEGIN
      GOTO QUIT_SP
   END

   SET @n_Cnt = 0 
   SELECT @n_Cnt = 1
   FROM STOCKTAKEPARMSTRATEGY WITH (NOLOCK)
   WHERE StockTakeKey = @c_StockTakeKey
   

   IF @n_Cnt = 1
   BEGIN
      IF EXISTS ( SELECT 1
                  FROM CCDETAIL WITH (NOLOCK)
                  WHERE CCkey = @c_StockTakeKey
                 )
      BEGIN
         GOTO QUIT_SP
      END

      DELETE STOCKTAKEPARMSTRATEGY WITH (ROWLOCK)
      WHERE StockTakeKey = @c_StockTakeKey

   END

   IF @c_SPName <> '' 
   BEGIN
      IF EXISTS (SELECT 1 FROM dbo.sysobjects WHERE name = RTRIM(@c_SPName) AND type = 'P')          
      BEGIN 
         SET @c_SQL = 'EXEC ' + @c_SPName + ' @c_StockTakeKey, @b_Success OUTPUT, @n_Err OUTPUT, @c_ErrMsg OUTPUT '          

         EXEC sp_executesql @c_SQL         
              , N'@c_StockTakeKey NVARCHAR(10), @b_Success Int OUTPUT, @n_Err Int OUTPUT, @c_ErrMsg NVARCHAR(250) OUTPUT'
              , @c_StockTakeKey
              , @b_Success OUTPUT          
              , @n_Err     OUTPUT           
              , @c_ErrMsg  OUTPUT 
       
         IF @b_Success <> 1     
         BEGIN    
            SET @n_Continue = 3    
            SET @n_err    =65010 
            SET @c_errmsg =  'NSQL' +  CONVERT(CHAR(5), @n_err) + ': Error Executing ' + RTRIM(@c_SPName) + '. (ispCCStrategy)' 
         END         

         GOTO QUIT_SP
      END
      ELSE
      BEGIN
         SET @n_Continue = 3    
         SET @n_err    =65020
         SET @c_errmsg = 'NSQL' + CONVERT(CHAR(5), @n_err) + ': Setup Stored Procedured: ' + RTRIM(@c_SPName) + ' Not Found. (ispCCStrategy)'
         GOTO QUIT_SP                    
      END
   END

   IF RTRIM(@c_Notes) = ''
   BEGIN
      SET @n_Continue = 3    
      SET @n_err    = 65030
      SET @c_errmsg = 'NSQL' + CONVERT(CHAR(5), @n_err) + ': Neither SQL statement nor Stored Procedured is setup. (ispCCStrategy)'
      GOTO QUIT_SP
   END 

   CREATE TABLE #RESULT 
      (  Storerkey   NVARCHAR(15)   NULL
      ,  Sku         NVARCHAR(20)   NULL
      ,  Loc         NVARCHAR(10)   NULL
      )

   SET @n_Cnt = 1
   SET @c_ParmsSQL = ''
   WHILE @n_Cnt <= 8
   BEGIN
      SET @c_Cnt = RTRIM(CONVERT(NVARCHAR(2), @n_Cnt))
      SET @c_Cnt = RIGHT('00'+ @c_Cnt,2)

      SET @c_SQL = N'SET @c_Parameter = @c_Parameter' + @c_Cnt
                 + ' SET @c_ParmField = @c_ParmField' + @c_Cnt
         
      EXEC sp_ExecuteSql @c_SQL         
              , N' @c_Parameter     NVARCHAR(125) OUTPUT
                 , @c_ParmField     NVARCHAR(30)  OUTPUT
                 , @c_Parameter01   NVARCHAR(125)
                 , @c_Parameter02   NVARCHAR(125)
                 , @c_Parameter03   NVARCHAR(125)
                 , @c_Parameter04   NVARCHAR(125)
                 , @c_Parameter05   NVARCHAR(125)
                 , @c_Parameter06   NVARCHAR(125)
                 , @c_Parameter07   NVARCHAR(125)
                 , @c_Parameter08   NVARCHAR(125)
                 , @c_ParmField01   NVARCHAR(30)
                 , @c_ParmField02   NVARCHAR(30)
                 , @c_ParmField03   NVARCHAR(30)
                 , @c_ParmField04   NVARCHAR(30)
                 , @c_ParmField05   NVARCHAR(30)
                 , @c_ParmField06   NVARCHAR(30)
                 , @c_ParmField07   NVARCHAR(30)
                 , @c_ParmField08   NVARCHAR(30)
                 ' 
              , @c_Parameter     OUTPUT
              , @c_ParmField     OUTPUT           
              , @c_Parameter01  
              , @c_Parameter02 
              , @c_Parameter03 
              , @c_Parameter04 
              , @c_Parameter05 
              , @c_Parameter06
              , @c_Parameter07
              , @c_Parameter08 
              , @c_ParmField01  
              , @c_ParmField02  
              , @c_ParmField03 
              , @c_ParmField04 
              , @c_ParmField05
              , @c_ParmField06
              , @c_ParmField07
              , @c_ParmField08
 

      SET @n_err = @@ERROR
      IF @n_err <> 0 
      BEGIN
         SET @n_Continue = 3
         SET @n_err = 65040
         SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_err) + ': Error Executing SQL. (ispCCStrategy)'
         GOTO QUIT_SP
      END

      IF RTRIM(@c_ParmField) <> ''
      BEGIN
         SET @n_idx = 0
         SET @n_idx = CHARINDEX('.', @c_ParmField, 1)

         SET @c_TableName = ''
         IF @n_idx > 0 
         BEGIN
            SET @c_TableName = LEFT(@c_ParmField, @n_idx - 1)
            SET @c_TableName = RTRIM(@c_TableName)
         END 

         IF CHARINDEX( 'FROM ' + @c_TableName, @c_Notes, 1) > 0 OR
            CHARINDEX( 'JOIN ' + @c_TableName, @c_Notes, 1) > 0
         BEGIN
            SET @c_ParmsSQL1 = ''
            SET @c_ParmsSQL2 = ''
            EXEC ispParseParameters
                  @c_Parameter
              ,   'string'
              ,   @c_ParmField
              ,   @c_ParmsSQL1   OUTPUT 
              ,   @c_ParmsSQL2   OUTPUT 
              ,   @b_Success     OUTPUT

            SET @n_err = @@ERROR
            IF @n_err <> 0 
            BEGIN
               SET @n_Continue = 3
               SET @n_err = 65050
               SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_err) + ': Error Executing ispParseParameters. (ispCCStrategy)'
               GOTO QUIT_SP
            END

            SET @c_ParmsSQL = @c_ParmsSQL + @c_ParmsSQL1 + ' ' + @c_ParmsSQL2 + ' '
         END
      END

      SET @n_Cnt = @n_Cnt + 1
   END

   SET @c_SQL = @c_Notes
   SET @n_idx = 0
   SET @n_idx = CHARINDEX('ORDER BY',@c_SQL,1)
   IF @n_idx > 0 
   BEGIN
      SET @c_SQLOrderBy = SUBSTRING(@c_SQL,@n_idx,LEN(@c_SQL) - @n_idx + 1)
      SET @c_SQL = SUBSTRING(@c_SQL,1,@n_idx - 1) 
   END

   SET @n_idx = 0
   SET @n_idx = CHARINDEX('GROUP BY',@c_SQL,1)
   IF @n_idx > 0 
   BEGIN
      SET @c_SQLGroupBy = SUBSTRING(@c_SQL,@n_idx,LEN(@c_SQL) - @n_idx + 1)
      SET @c_SQL = SUBSTRING(@c_SQL,1,@n_idx - 1) 
   END

   SET @c_SQL = @c_SQL + ' '
              + @c_ParmsSQL + ' '
              + @c_SQLGroupBy + ' '
              + @c_SQLOrderBy

   IF LEN(@c_SQL) > 0
   BEGIN
      INSERT INTO #RESULT (Storerkey, Sku, Loc)
      EXEC (@c_SQL)

      SET @n_err = @@ERROR
      IF @n_err <> 0 
      BEGIN
         SET @n_Continue = 3
         SET @n_err = 65060
         SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_err) + ': Error Executing SQL. (ispCCStrategy)'
         GOTO QUIT_SP
      END
   END

   IF EXISTS ( SELECT 1
               FROM #RESULT
            )
   BEGIN
      INSERT INTO STOCKTAKEPARMSTRATEGY
         (  StockTakeKey
         ,  Storerkey
         ,  Sku
         ,  Loc
         )
      SELECT @c_Stocktakekey
         ,  Storerkey
         ,  Sku
         ,  Loc
      FROM #RESULT
   END
QUIT_SP:
   SET @c_StrategySQL    = '' 
   SET @c_StrategySkuSQL = ''
   SET @c_StrategyLocSQL = ''

   IF EXISTS ( SELECT 1
               FROM STOCKTAKEPARMSTRATEGY WITH (NOLOCK)
               WHERE StockTakeKey = @c_StockTakeKey
               AND   Sku <> ''
             ) 
   BEGIN
      SET @c_StrategySkuSQL = 'AND EXISTS ( '
                            + 'SELECT 1 FROM STOCKTAKEPARMSTRATEGY WITH (NOLOCK) '
                            + 'WHERE StockTakeKey = N''' + RTRIM(@c_StockTakeKey) + ''' '
                            + 'AND Storerkey = LOTxLOCxID.Storerkey '
                            + 'AND Sku = LOTxLOCxID.Sku )'
   END

   IF EXISTS ( SELECT 1
               FROM STOCKTAKEPARMSTRATEGY WITH (NOLOCK)
               WHERE StockTakeKey = @c_StockTakeKey
               AND   Loc <> ''
             ) 
   BEGIN
      SET @c_StrategyLocSQL = 'AND EXISTS ( '
                            + 'SELECT 1 FROM STOCKTAKEPARMSTRATEGY WITH (NOLOCK) '
                            + 'WHERE StockTakeKey = N''' + RTRIM(@c_StockTakeKey) + ''' '
                            + 'AND Loc = LOC.Loc )'
   END
   
   IF @c_StrategySkuSQL <> '' AND @c_StrategyLocSQL <> ''
   BEGIN
       SET @c_StrategySQL = 'AND EXISTS ( '
                            + 'SELECT 1 FROM STOCKTAKEPARMSTRATEGY WITH (NOLOCK) '
                            + 'WHERE StockTakeKey = N''' + RTRIM(@c_StockTakeKey) + ''' '
                            + 'AND Storerkey = LOTxLOCxID.Storerkey '
                            + 'AND Sku = LOTxLOCxID.Sku '
                            + 'AND Loc = LOC.Loc )'
   END 
   ELSE
   BEGIN
       SET @c_StrategySQL = @c_StrategySkuSQL + ' ' + @c_StrategyLocSQL
   END 

   IF @n_Continue=3  -- Error Occured - Process And Return
   BEGIN
      SET @b_Success = 0
      IF  @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt
      BEGIN
         ROLLBACK TRAN
      END
      ELSE
      BEGIN
         WHILE @@TRANCOUNT > @n_StartTCnt
         BEGIN
            COMMIT TRAN
         END
      END

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'ispCCStrategy'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
   END
   ELSE
   BEGIN
      SET @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
   END
END -- procedure

GO