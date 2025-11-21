SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Copyright: LFL                                                             */
/* Purpose: isp_Bartender_JP_PRICETAGLB_GetParm                               */
/*                                                                            */
/* Modifications log:                                                         */
/*                                                                            */
/* Date       Rev  Author     Purposes                                        */
/* 2020-06-15 1.0  WLChooi    Created (WMS-13722)                             */
/******************************************************************************/

CREATE PROC [dbo].[isp_Bartender_JP_PRICETAGLB_GetParm]
(  @parm01            NVARCHAR(250),
   @parm02            NVARCHAR(250),
   @parm03            NVARCHAR(250),
   @parm04            NVARCHAR(250),
   @parm05            NVARCHAR(250),
   @parm06            NVARCHAR(250),
   @parm07            NVARCHAR(250),
   @parm08            NVARCHAR(250),
   @parm09            NVARCHAR(250),
   @parm10            NVARCHAR(250),
   @b_debug           INT = 0
)
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_intFlag          INT,
           @n_CntRec           INT,
           @c_SQL              NVARCHAR(4000),
           @c_SQLSORT          NVARCHAR(4000),
           @c_SQLJOIN          NVARCHAR(4000),
           @c_condition1       NVARCHAR(150) ,
           @c_condition2       NVARCHAR(150),
           @c_SQLGroup         NVARCHAR(4000),
           @c_SQLOrdBy         NVARCHAR(150)

  DECLARE  @d_Trace_StartTime  DATETIME,
           @d_Trace_EndTime    DATETIME,
           @c_Trace_ModuleName NVARCHAR(20),
           @d_Trace_Step1      DATETIME,
           @c_Trace_Step1      NVARCHAR(20),
           @c_UserName         NVARCHAR(20),
           @n_cnt              INT,
           @c_mode             NVARCHAR(1),
           @c_sku              NVARCHAR(20),
           @c_ExecStatements   NVARCHAR(4000),
           @c_ExecArguments    NVARCHAR(4000),
           @n_NoOfCopy         INT

   SET @d_Trace_StartTime = GETDATE()
   SET @c_Trace_ModuleName = ''

    -- SET RowNo = 0
   SET @c_SQL = ''
   SET @c_mode = '0'
   SET @c_SQLJOIN = ''
   SET @c_condition1 = ''
   SET @c_condition2= ''
   SET @c_SQLOrdBy = ''
   SET @c_SQLGroup = ''
   SET @c_ExecStatements = ''
   SET @c_ExecArguments = ''
   SET @n_cnt = 1

   IF ISNULL(@parm02,'') = '' GOTO EXIT_SP
   IF ISNULL(@parm03,'') = 0 SET @parm03 = 1

   SET @n_NoOfCopy = @parm03

   CREATE TABLE #TEMP_SKU (
      PARM1     NVARCHAR(80),
      PARM2     NVARCHAR(80),
      PARM3     NVARCHAR(80),
      PARM4     NVARCHAR(80),
      PARM5     NVARCHAR(80),
      PARM6     NVARCHAR(80),
      PARM7     NVARCHAR(80),
      PARM8     NVARCHAR(80),
      PARM9     NVARCHAR(80),
      PARM10    NVARCHAR(80),
      KEY1      NVARCHAR(80),
      KEY2      NVARCHAR(80),
      KEY3      NVARCHAR(80),
      KEY4      NVARCHAR(80),
      KEY5      NVARCHAR(80) )

   --Check if it is SKU or ALTSKU or ManufacturerSKU, IF AltSku or ManufacturerSKU, find SKU
   IF NOT EXISTS (SELECT 1 FROM SKU (NOLOCK) WHERE SKU = @parm02 AND Storerkey = @Parm01)
   BEGIN
      IF EXISTS(SELECT 1 FROM SKU (NOLOCK) WHERE ALTSKU = @parm02 AND Storerkey = @Parm01)
      BEGIN
         SELECT @parm02 = SKU
         FROM SKU (NOLOCK) 
         WHERE ALTSKU = @parm02 AND Storerkey = @Parm01
      END
      ELSE IF EXISTS(SELECT 1 FROM SKU (NOLOCK) WHERE MANUFACTURERSKU = @parm02 AND Storerkey = @Parm01)
      BEGIN
         SELECT @parm02 = SKU
         FROM SKU (NOLOCK) 
         WHERE MANUFACTURERSKU = @parm02 AND Storerkey = @Parm01
      END
   END

   WHILE @n_NoOfCopy >= 1
   BEGIN
      INSERT INTO #TEMP_SKU
      SELECT PARM1 = @Parm01, PARM2 = @parm02, 
             PARM3 = @n_cnt,
             PARM4 = '', PARM5 = '', PARM6 = '', PARM7 = '', 
             PARM8 = '', PARM9 = '', PARM10 = '', 
             Key1 = 'Storerkey', Key2 = 'SKU', Key3 = '', Key4 = '', Key5 = '' 

      SET @n_NoOfCopy = @n_NoOfCopy - 1
      SET @n_cnt = @n_cnt + 1
   END

   SET @c_SQLJOIN = 'SELECT * FROM #TEMP_SKU ORDER BY CAST(PARM3 AS INT) ASC '

   SET @c_SQL = @c_SQLJOIN

   SET @c_ExecArguments = N'  @parm01           NVARCHAR(80) '      
                          +', @parm02           NVARCHAR(80) '      
                          +', @parm03           NVARCHAR(80) '   
                          +', @parm04           NVARCHAR(80) '  
                                    
   EXEC sp_ExecuteSql     @c_SQL       
                        , @c_ExecArguments      
                        , @parm01      
                        , @parm02     
                        , @parm03 
                        , @parm04

EXIT_SP:

   SET @d_Trace_EndTime = GETDATE()
   SET @c_UserName = SUSER_SNAME()

   IF OBJECT_ID('tempdb..#TEMP_SKU') IS NOT NULL
      DROP TABLE #TEMP_SKU

END -- procedure

GO