SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Trigger:  ispLottableRule_Wrapper                                    */
/* Creation Date: 22-Sep-2006                                           */
/* Copyright: IDS                                                       */
/* Written by: Vicky                                                    */
/*                                                                      */
/* Purpose:  Generic LottableRule Wrapper                               */
/*                                                                      */
/* Output Parameters:  None                                             */
/*                                                                      */
/* PVCS Version: 1.2                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Who      Purpose                                        */
/* 19-Jan-2007  MaryVong Add RDT compatible messages                    */
/* 30-Nov-2007  Vicky    Add in Sourcekey & Sourcetype as parameter     */
/*                       (Vicky01)                                      */
/* 01-Jun-2009  James    Change sourcekey field from 10 to 15 char      */
/* 24-Aug-2013  ChewKP   SOS#287338 - Codelkup Priority by Storerkey    */
/*                       (ChewKP01)                                     */
/* 01-Apr-2014  Ung      SOS306108 Expand L01-3 to for decode barcode   */
/* 27-May-2014  TKLIM    Added Lottables 06-15                          */
/* 05-NOV-2014  CSCHONG  Add new input parameter (CS01)                 */
/* 13-Apr-2015  CSCHONG  fix bugs SOS338163 AND RDT  bugs (CS02)        */
/* 30-Nov-2017  NJOW01   retrieve stored proc name from codelkup for    */
/*                       eWMS.                                          */
/* 29-Sep-2020  Wan01    Fix Dynamic Select statement issue             */
/* 27-Nov-2020  Wan02    LFWM-2438 - UAT  Philippines  PH SCE Lottable13*/
/*                       Not Autocomputing                              */
/************************************************************************/

CREATE PROC [dbo].[ispLottableRule_Wrapper] (
        @c_SPName                NVARCHAR(250)
      , @c_Listname              NVARCHAR(10)
      , @c_Storerkey             NVARCHAR(15)
      , @c_Sku                   NVARCHAR(20)
      , @c_LottableLabel         NVARCHAR(20)
      , @c_Lottable01Value       NVARCHAR(60)
      , @c_Lottable02Value       NVARCHAR(60)
      , @c_Lottable03Value       NVARCHAR(60)
      , @dt_Lottable04Value      DATETIME
      , @dt_Lottable05Value      DATETIME
      , @c_Lottable06Value       NVARCHAR(60)   = ''
      , @c_Lottable07Value       NVARCHAR(60)   = ''
      , @c_Lottable08Value       NVARCHAR(60)   = ''
      , @c_Lottable09Value       NVARCHAR(60)   = ''
      , @c_Lottable10Value       NVARCHAR(60)   = ''
      , @c_Lottable11Value       NVARCHAR(60)   = ''
      , @c_Lottable12Value       NVARCHAR(60)   = ''
      , @dt_Lottable13Value      DATETIME       = NULL
      , @dt_Lottable14Value      DATETIME       = NULL
      , @dt_Lottable15Value      DATETIME       = NULL
      , @c_Lottable01            NVARCHAR(18)            OUTPUT
      , @c_Lottable02            NVARCHAR(18)            OUTPUT
      , @c_Lottable03            NVARCHAR(18)            OUTPUT
      , @dt_Lottable04           DATETIME                OUTPUT
      , @dt_Lottable05           DATETIME                OUTPUT
      , @c_Lottable06            NVARCHAR(30)   = ''     OUTPUT
      , @c_Lottable07            NVARCHAR(30)   = ''     OUTPUT
      , @c_Lottable08            NVARCHAR(30)   = ''     OUTPUT
      , @c_Lottable09            NVARCHAR(30)   = ''     OUTPUT
      , @c_Lottable10            NVARCHAR(30)   = ''     OUTPUT
      , @c_Lottable11            NVARCHAR(30)   = ''     OUTPUT
      , @c_Lottable12            NVARCHAR(30)   = ''     OUTPUT
      , @dt_Lottable13           DATETIME       = NULL   OUTPUT
      , @dt_Lottable14           DATETIME       = NULL   OUTPUT
      , @dt_Lottable15           DATETIME       = NULL   OUTPUT
      , @b_Success               int = 1                 OUTPUT
      , @n_Err                   int = 0                 OUTPUT
      , @c_Errmsg                NVARCHAR(250)  = ''     OUTPUT
      , @c_Sourcekey             NVARCHAR(15)   = ''     -- (Vicky01)
      , @c_Sourcetype            NVARCHAR(20)   = ''    -- (Vicky01)
      , @c_type                  NVARCHAR(10)   = ''--(CS01)
      , @c_PrePost               NVARCHAR(10) = '')--NJOW01
AS 
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
   DECLARE @cSQL   NVARCHAR(2000),
           @cSQLStatement   NVARCHAR(2000), 
           @cSQLParms       NVARCHAR(2000)

   DECLARE @b_debug  int 
   SET @b_debug = 0

   DECLARE 
   @c_ParameterName NVARCHAR(200),          @n_OrdinalPosition INT, 
   @c_Rtn           NVARCHAR(10) --NJOW01
  -- @n_ErrNo          INT, @n_check   INT   --(CS02)

   DECLARE @c_UserDefineValue    NVARCHAR(30) --(CS02)

    SET @cSQLStatement = ''
    SET @cSql = '' 
   -- SET @n_check = 0

   --NJOW01
   IF ISNULL(@c_SPName,'') = '' AND ISNULL(@c_Listname,'') <> ''
   BEGIN          
        SET @cSQLStatement = ''
        
        SELECT @c_Rtn = CASE WHEN @c_ListName = 'LOTTABLE01' AND ISNULL(@c_Lottable01Value,'') = '' THEN 'Y'  
                           WHEN @c_ListName = 'LOTTABLE02' AND ISNULL(@c_Lottable02Value,'') = '' THEN 'Y'  
                           WHEN @c_ListName = 'LOTTABLE03' AND ISNULL(@c_Lottable03Value,'') = '' THEN 'Y'  
                           WHEN @c_ListName = 'LOTTABLE04' AND (CONVERT(NVARCHAR(8) ,@dt_Lottable04Value ,112) = '19000101' OR @dt_Lottable04Value IS NULL) THEN 'Y'  --(Wan02)
                           WHEN @c_ListName = 'LOTTABLE05' AND (CONVERT(NVARCHAR(8) ,@dt_Lottable05Value ,112) = '19000101' OR @dt_Lottable05Value IS NULL) THEN 'Y'  --(Wan02)
                           WHEN @c_ListName = 'LOTTABLE06' AND ISNULL(@c_Lottable06Value,'') = '' THEN 'Y'  
                           WHEN @c_ListName = 'LOTTABLE07' AND ISNULL(@c_Lottable07Value,'') = '' THEN 'Y'  
                           WHEN @c_ListName = 'LOTTABLE08' AND ISNULL(@c_Lottable08Value,'') = '' THEN 'Y'  
                           WHEN @c_ListName = 'LOTTABLE09' AND ISNULL(@c_Lottable09Value,'') = '' THEN 'Y'  
                           WHEN @c_ListName = 'LOTTABLE10' AND ISNULL(@c_Lottable10Value,'') = '' THEN 'Y'  
                           WHEN @c_ListName = 'LOTTABLE11' AND ISNULL(@c_Lottable11Value,'') = '' THEN 'Y'  
                           WHEN @c_ListName = 'LOTTABLE12' AND ISNULL(@c_Lottable12Value,'') = '' THEN 'Y'  
                           WHEN @c_ListName = 'LOTTABLE13' AND (CONVERT(NVARCHAR(8) ,@dt_Lottable13Value ,112) = '19000101' OR @dt_Lottable13Value IS NULL) THEN 'Y' --(Wan02) 
                           WHEN @c_ListName = 'LOTTABLE14' AND (CONVERT(NVARCHAR(8) ,@dt_Lottable14Value ,112) = '19000101' OR @dt_Lottable13Value IS NULL) THEN 'Y' --(Wan02) 
                           WHEN @c_ListName = 'LOTTABLE15' AND (CONVERT(NVARCHAR(8) ,@dt_Lottable15Value ,112) = '19000101' OR @dt_Lottable15Value IS NULL) THEN 'Y' --(Wan02) 
                       ELSE 'N' END      
      
      IF @c_Rtn = 'Y'
         GOTO QUIT                     
        
      SELECT @cSQLStatement = 
      ' SELECT TOP 1 @c_SPName = CL.Long,
                   @c_LottableLabel =  SKU.Lottable'  + RIGHT(RTRIM(@c_ListName),2) + 'Label ' +
      ' FROM CODELKUP CL (NOLOCK) ' +
      ' JOIN SKU (NOLOCK) ON CL.Code = SKU.Lottable'  + RIGHT(RTRIM(@c_ListName),2) + 'Label ' +
      ' WHERE CL.Listname = @c_Listname ' +
      CASE WHEN @c_PrePost IN('PRE','BOTH') THEN
          ' AND CL.Short IN(''PRE'',''BOTH'') '
      ELSE '' END +    
      ' AND SKU.Storerkey = @c_Storerkey 
      AND SKU.Sku = @c_Sku 
      AND (CL.Storerkey = @c_Storerkey OR ISNULL(CL.Storerkey,'''')='''')
      ORDER BY CL.Storerkey DESC '
      
      EXEC sp_executesql @cSQLStatement,
                 N'@c_Storerkey NVARCHAR(15), @c_Sku NVARCHAR(20), @c_Listname NVARCHAR(10), @c_SPName NVARCHAR(250) OUTPUT, @c_LottableLabel NVARCHAR(20) OUTPUT ',
                 @c_Storerkey,
                 @c_Sku,      
                 @c_Listname,
                 @c_SPName OUTPUT,
                 @c_LottableLabel OUTPUT                 
      
      IF ISNULL(@c_SPName,'') = '' 
         GOTO QUIT
      
      SET @cSQLStatement = ''
   END
  
   IF @c_SPName = '' OR @c_SPName IS NULL
   BEGIN
      SET @b_Success = 0
      SET @n_Err = 61301    
      SET @c_Errmsg = CONVERT ( NVARCHAR(5), @n_Err) + ' Stored Proc Not Setup. (ispLottableRule_Wrapper)'
      GOTO QUIT
   END
   
   IF @c_LottableLabel = '' OR @c_LottableLabel IS NULL
   BEGIN
      SET @b_Success = 0
      SET @n_Err = 61302    
      SET @c_Errmsg = CONVERT ( NVARCHAR(5), @n_Err) + ' Lottable Label Not Setup. (ispLottableRule_Wrapper)'
      GOTO QUIT
   END
   
   IF @c_SPName = '' OR @c_SPName IS NULL
   BEGIN
      IF (@c_LottableLabel <> '' AND @c_LottableLabel IS NOT NULL)
      BEGIN
         SELECT @c_SPName = dbo.fnc_RTrim(LONG)
         FROM CODELKUP (NOLOCK)
         WHERE LISTNAME = dbo.fnc_RTrim(@c_ListName)
         AND   CODE = dbo.fnc_RTrim(@c_LottableLabel)   
         ORDER BY 
         CASE WHEN StorerKey = @c_Storerkey THEN 1 ELSE 2 END -- (ChewKP01)
      END
   END

   IF @b_debug = 1
   BEGIN
     SELECT '@c_SPName', @c_SPName
   END

   IF EXISTS (SELECT 1 FROM dbo.sysobjects WHERE name = dbo.fnc_RTrim(@c_SPName) AND type = 'P')
   BEGIN
      /*CS01 Start
      IF EXISTS(SELECT 1
                            FROM sys.parameters AS p
                            JOIN sys.types AS t ON t.user_type_id = p.user_type_id
                            JOIN dbo.sysobjects AS o ON o.id=p.object_id
                            WHERE   P.name LIKE '@c_type%' 
                            AND o.name = dbo.fnc_RTrim(@c_SPName) AND o.type = 'P')
      BEGIN
      SET @cSQLStatement = N'EXEC ' + dbo.fnc_RTrim(@c_SPName) + 
                         + ' @c_Storerkey, @c_Sku, '
                         + ' @c_Lottable01Value, @c_Lottable02Value, @c_Lottable03Value, @dt_Lottable04Value, @dt_Lottable05Value, '
                         + ' @c_Lottable06Value, @c_Lottable07Value, @c_Lottable08Value, @c_Lottable09Value, @c_Lottable10Value, '
                         + ' @c_Lottable11Value, @c_Lottable12Value, @dt_Lottable13Value, @dt_Lottable14Value, @dt_Lottable15Value, '
                         + ' @c_Lottable01 OUTPUT, @c_Lottable02 OUTPUT, @c_Lottable03 OUTPUT, @dt_Lottable04 OUTPUT, @dt_Lottable05 OUTPUT,'
                         + ' @c_Lottable06 OUTPUT, @c_Lottable07 OUTPUT, @c_Lottable08 OUTPUT, @c_Lottable09 OUTPUT, @c_Lottable10 OUTPUT, '
                         + ' @c_Lottable11 OUTPUT, @c_Lottable12 OUTPUT, @dt_Lottable13 OUTPUT, @dt_Lottable14 OUTPUT, @dt_Lottable15 OUTPUT, '
                         + ' @b_Success OUTPUT, @n_Err OUTPUT, @c_Errmsg OUTPUT, '
                         + ' @c_Sourcekey, @c_SourceType, @c_LottableLabel,@c_Type ' -- (Vicky01)  --(CS01)
     END
     ELSE
     BEGIN

         SET @cSQLStatement = N'EXEC ' + dbo.fnc_RTrim(@c_SPName) + 
                         + ' @c_Storerkey, @c_Sku, '
                         + ' @c_Lottable01Value, @c_Lottable02Value, @c_Lottable03Value, @dt_Lottable04Value, @dt_Lottable05Value, '
                         + ' @c_Lottable06Value, @c_Lottable07Value, @c_Lottable08Value, @c_Lottable09Value, @c_Lottable10Value, '
                         + ' @c_Lottable11Value, @c_Lottable12Value, @dt_Lottable13Value, @dt_Lottable14Value, @dt_Lottable15Value, '
                         + ' @c_Lottable01 OUTPUT, @c_Lottable02 OUTPUT, @c_Lottable03 OUTPUT, @dt_Lottable04 OUTPUT, @dt_Lottable05 OUTPUT,'
                         + ' @c_Lottable06 OUTPUT, @c_Lottable07 OUTPUT, @c_Lottable08 OUTPUT, @c_Lottable09 OUTPUT, @c_Lottable10 OUTPUT, '
                         + ' @c_Lottable11 OUTPUT, @c_Lottable12 OUTPUT, @dt_Lottable13 OUTPUT, @dt_Lottable14 OUTPUT, @dt_Lottable15 OUTPUT, '
                         + ' @b_Success OUTPUT, @n_Err OUTPUT, @c_Errmsg OUTPUT, '
                         + ' @c_Sourcekey, @c_SourceType, @c_LottableLabel ' 
     END
     CS01 END*/

     /*CS01 Start*/

     DECLARE Cur_Parameters CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT PARAMETER_NAME, ORDINAL_POSITION
      FROM [INFORMATION_SCHEMA].[PARAMETERS] 
      WHERE SPECIFIC_NAME = @c_SPName 
      ORDER BY ORDINAL_POSITION

      OPEN Cur_Parameters
      FETCH NEXT FROM Cur_Parameters INTO @c_ParameterName, @n_OrdinalPosition
      WHILE @@FETCH_STATUS <> -1
      BEGIN
      set @cSQLStatement = 'EXEC '  + @c_SPName
      SET @cSQL = RTRIM(@cSQL) + CASE WHEN @n_OrdinalPosition = 1 THEN ' ' ELSE ' ,' END + 
      CASE @c_ParameterName 
         WHEN '@c_Storerkey'        THEN '@c_Storerkey' 
         WHEN '@c_Sku'              THEN '@c_Sku'
         WHEN '@c_Lottable01Value'  THEN '@c_Lottable01Value'
         WHEN '@c_Lottable02Value'  THEN '@c_Lottable02Value' 
         WHEN '@c_Lottable03Value'  THEN '@c_Lottable03Value'
         WHEN '@dt_Lottable04Value'  THEN '@dt_Lottable04Value' 
         WHEN '@dt_Lottable05Value'  THEN '@dt_Lottable05Value'
         WHEN '@c_Lottable06Value'  THEN '@c_Lottable06Value'
         WHEN '@c_Lottable07Value'  THEN '@c_Lottable07Value'
         WHEN '@c_Lottable08Value'  THEN '@c_Lottable08Value'
         WHEN '@c_Lottable09Value'  THEN '@c_Lottable09Value' 
         WHEN '@c_Lottable10Value'  THEN '@c_Lottable10Value'
         WHEN '@c_Lottable11Value'  THEN '@c_Lottable11Value'
         WHEN '@c_Lottable12Value'  THEN '@c_Lottable12Value'
         WHEN '@dt_Lottable13Value'  THEN '@dt_Lottable13Value'
         WHEN '@dt_Lottable14Value'  THEN '@dt_Lottable14Value' 
         WHEN '@dt_Lottable15Value'  THEN '@dt_Lottable15Value'
         WHEN '@c_Lottable01'       THEN '@c_Lottable01 OUTPUT '
         WHEN '@c_Lottable02'       THEN '@c_Lottable02 OUTPUT '
         WHEN '@c_Lottable03'       THEN '@c_Lottable03 OUTPUT ' 
         WHEN '@dt_Lottable04'      THEN '@dt_Lottable04 OUTPUT '
         WHEN '@dt_Lottable05'      THEN '@dt_Lottable05 OUTPUT '  
         WHEN '@c_Lottable06'       THEN '@c_Lottable06 OUTPUT ' 
         WHEN '@c_Lottable07'       THEN '@c_Lottable07 OUTPUT ' 
         WHEN '@c_Lottable08'       THEN '@c_Lottable08 OUTPUT ' 
         WHEN '@c_Lottable09'       THEN '@c_Lottable09 OUTPUT '
         WHEN '@c_Lottable10'       THEN '@c_Lottable10 OUTPUT '  
         WHEN '@c_Lottable11'       THEN '@c_Lottable11 OUTPUT ' 
         WHEN '@c_Lottable12'       THEN '@c_Lottable12 OUTPUT ' 
         WHEN '@dt_Lottable13'      THEN '@dt_Lottable13 OUTPUT '
         WHEN '@dt_Lottable14'      THEN '@dt_Lottable14 OUTPUT ' 
         WHEN '@dt_Lottable15'      THEN '@dt_Lottable15 OUTPUT '  
         WHEN '@b_Success'          THEN '@b_Success OUTPUT'
         WHEN '@n_Err'              THEN '@n_Err OUTPUT '
         WHEN '@n_ErrNo'            THEN '@n_Err OUTPUT '      --(CS02)
         WHEN '@c_Errmsg'           THEN '@c_Errmsg OUTPUT'
         WHEN '@c_Sourcekey'        THEN '@c_Sourcekey '
         WHEN '@c_SourceType'       THEN '@c_SourceType ' 
         WHEN '@c_LottableLabel'    THEN '@c_LottableLabel '
         WHEN '@c_Type'             THEN '@c_Type' 
         WHEN '@c_UserDefineValue'  THEN '@c_UserDefineValue'                --(CS02)                                      --(CS02)
      END 


--    IF @c_ParameterName = '@n_ErrNo' 
--    BEGIN
--      SET @n_check =1 
--    END

   FETCH NEXT FROM Cur_Parameters INTO @c_ParameterName, @n_OrdinalPosition
END 
CLOSE Cur_Parameters
DEALLOCATE Cur_Parameters 

SET @cSQLStatement = @cSQLStatement + @cSQL

     /*CS01 End*/
--END
      SET @cSQLParms = N'@c_Storerkey              NVARCHAR(15)'
                     + ', @c_Sku                   NVARCHAR(20)'
                     + ', @c_Lottable01Value       NVARCHAR(60)'
                     + ', @c_Lottable02Value       NVARCHAR(60)'
                     + ', @c_Lottable03Value       NVARCHAR(60)'
                     + ', @dt_Lottable04Value      DATETIME'    
                     + ', @dt_Lottable05Value      DATETIME'    
                     + ', @c_Lottable06Value       NVARCHAR(60)'
                     + ', @c_Lottable07Value       NVARCHAR(60)'
                     + ', @c_Lottable08Value       NVARCHAR(60)'
                     + ', @c_Lottable09Value       NVARCHAR(60)'
                     + ', @c_Lottable10Value       NVARCHAR(60)'
                     + ', @c_Lottable11Value       NVARCHAR(60)'
                     + ', @c_Lottable12Value       NVARCHAR(60)'
                     + ', @dt_Lottable13Value      DATETIME'    
                     + ', @dt_Lottable14Value      DATETIME'    
                     + ', @dt_Lottable15Value      DATETIME'    
                     + ', @c_Lottable01            NVARCHAR(18)   OUTPUT'
                     + ', @c_Lottable02            NVARCHAR(18)   OUTPUT'
                     + ', @c_Lottable03            NVARCHAR(18)   OUTPUT'
                     + ', @dt_Lottable04           DATETIME       OUTPUT'
                     + ', @dt_Lottable05           DATETIME       OUTPUT'
                     + ', @c_Lottable06            NVARCHAR(30)   OUTPUT'
                     + ', @c_Lottable07            NVARCHAR(30)   OUTPUT'
                     + ', @c_Lottable08            NVARCHAR(30)   OUTPUT'
                     + ', @c_Lottable09            NVARCHAR(30)   OUTPUT'
                     + ', @c_Lottable10            NVARCHAR(30)   OUTPUT'
                     + ', @c_Lottable11            NVARCHAR(30)   OUTPUT'
                     + ', @c_Lottable12            NVARCHAR(30)   OUTPUT'
                     + ', @dt_Lottable13           DATETIME       OUTPUT'
                     + ', @dt_Lottable14           DATETIME       OUTPUT'
                     + ', @dt_Lottable15           DATETIME       OUTPUT'
                     + ', @b_Success               int            OUTPUT'
                     + ', @n_Err                   int            OUTPUT'
                 --    + ', @n_ErrNo                 int            OUTPUT'
                     + ', @c_Errmsg                NVARCHAR(250)  OUTPUT'
                     + ', @c_Sourcekey             NVARCHAR(15)'         
                     + ', @c_SourceType            NVARCHAR(20)'         
                     + ', @c_LottableLabel         NVARCHAR(20)'
                     + ', @c_Type                  NVARCHAR(10) '        --(CS01)
                     + ', @c_UserDefineValue       NVARCHAR(30) '        --(CS02) 
      
      EXEC sp_ExecuteSQL @cSQLStatement
                        ,@cSQLParms
                        ,@c_Storerkey
                        ,@c_Sku
                        ,@c_Lottable01Value
                        ,@c_Lottable02Value    
                        ,@c_Lottable03Value    
                        ,@dt_Lottable04Value    
                        ,@dt_Lottable05Value    
                        ,@c_Lottable06Value 
                        ,@c_Lottable07Value 
                        ,@c_Lottable08Value 
                        ,@c_Lottable09Value 
                        ,@c_Lottable10Value 
                        ,@c_Lottable11Value 
                        ,@c_Lottable12Value 
                        ,@dt_Lottable13Value
                        ,@dt_Lottable14Value
                        ,@dt_Lottable15Value
                        ,@c_Lottable01       OUTPUT
                        ,@c_Lottable02       OUTPUT
                        ,@c_Lottable03       OUTPUT
                        ,@dt_Lottable04      OUTPUT
                        ,@dt_Lottable05      OUTPUT
                        ,@c_Lottable06       OUTPUT
                        ,@c_Lottable07       OUTPUT
                        ,@c_Lottable08       OUTPUT
                        ,@c_Lottable09       OUTPUT
                        ,@c_Lottable10       OUTPUT
                        ,@c_Lottable11       OUTPUT
                        ,@c_Lottable12       OUTPUT
                        ,@dt_Lottable13      OUTPUT
                        ,@dt_Lottable14      OUTPUT
                        ,@dt_Lottable15      OUTPUT
                        ,@b_Success          OUTPUT
                        ,@n_Err              OUTPUT
                      --  ,@n_ErrNo            OUTPUT
                        ,@c_Errmsg           OUTPUT
                        ,@c_SourceKey 
                        ,@c_SourceType
                        ,@c_LottableLabel
                        ,@c_type                --(CS01)
                        ,@c_UserDefineValue     --(CS02)   
   END


   IF @b_debug = 1
   BEGIN
      SELECT  @c_Lottable01      '@c_Lottable01'   
            , @c_Lottable02      '@c_Lottable02'   
            , @c_Lottable03      '@c_Lottable03'   
            , @dt_Lottable04     '@dt_Lottable04'  
            , @dt_Lottable05     '@dt_Lottable05'  
            , @c_Lottable06      '@c_Lottable06'   
            , @c_Lottable07      '@c_Lottable07'   
            , @c_Lottable08      '@c_Lottable08'   
            , @c_Lottable09      '@c_Lottable09'   
            , @c_Lottable10      '@c_Lottable10'   
            , @c_Lottable11      '@c_Lottable11'   
            , @c_Lottable12      '@c_Lottable12'   
            , @dt_Lottable13     '@dt_Lottable13'  
            , @dt_Lottable14     '@dt_Lottable14'  
            , @dt_Lottable15     '@dt_Lottable15'  
   END

--
--    IF @n_check = 1
--
--    BEGIN
--
--      SET @n_Err = @n_ErrNo
--
--    END

QUIT:
END -- procedure


GO