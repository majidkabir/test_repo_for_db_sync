SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/******************************************************************************/
/* Copyright: IDS                                                             */
/* Purpose: isp_Bartender_IT69_GetParm                                        */
/*                                                                            */
/* Modifications log:                                                         */
/*                                                                            */
/* Date       Rev  Author     Purposes                                        */
/* 2018-07-25 1.0  CSCHONG    Created(WMS-5634)                               */
/* 2018-10-15 1.1  FayLiuHY   Remove storerkey restriction (Fy01)             */
/* 2023-06-08 1.2  CSCHONG    change print line from main to sub (CS01)       */
/******************************************************************************/

CREATE   PROC [dbo].[isp_Bartender_IT69_GetParm]
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

   DECLARE
      @c_SQL             NVARCHAR(4000),
      @c_SQLSORT         NVARCHAR(4000),
      @c_SQLJOIN         NVARCHAR(4000),
      @c_condition1      NVARCHAR(150) ,
      @c_condition2      NVARCHAR(150),
      @c_SQLGroup        NVARCHAR(4000),
      @c_SQLOrdBy        NVARCHAR(150),
      @c_SQLinsert       NVARCHAR(4000) ,
      @c_SQLSelect       NVARCHAR(4000),
      @c_PrintbyASN      NVARCHAR(5),
      @c_PrintbySKU      NVARCHAR(5),
      @c_PrintbyIT69     NVARCHAR(5)



  DECLARE  @d_Trace_StartTime   DATETIME,
           @d_Trace_EndTime    DATETIME,
           @c_Trace_ModuleName NVARCHAR(20),
           @d_Trace_Step1      DATETIME,
           @c_Trace_Step1      NVARCHAR(20),
           @c_UserName         NVARCHAR(20),
           @c_getUCCno         NVARCHAR(20),
           @c_getUdef09        NVARCHAR(30),
           @c_ExecStatements   NVARCHAR(4000),
           @c_ExecArguments    NVARCHAR(4000),
           @c_Pickdetkey       NVARCHAR(50),
           @c_storerkey        NVARCHAR(20),
           @n_Pqty             INT,
           @n_rowno            INT

   SET @d_Trace_StartTime = GETDATE()
   SET @c_Trace_ModuleName = ''

    -- SET RowNo = 0
    SET @c_SQL = ''
    SET @c_SQLJOIN = ''
    SET @c_condition1 = ''
    SET @c_condition2= ''
    SET @c_SQLOrdBy = ''
    SET @c_SQLGroup = ''
    SET @c_ExecStatements = ''
    SET @c_ExecArguments = ''
    SET @c_SQLinsert = ''
    SET @c_SQLSelect = ''
    SET @c_PrintbyASN = 'N'
    SET @c_PrintbySKU = 'N'
    SET @c_PrintbyIT69 = 'N'

  IF @parm05 = '1' AND EXISTS (SELECT 1 FROM RECEIPT WITH (NOLOCK)
                               WHERE receiptkey = @Parm01)
    BEGIN

    SET @c_PrintbyASN = 'Y'

  END

  IF @parm05 <> '1' AND EXISTS (SELECT 1 FROM SKU WITH (NOLOCK)
                                WHERE SKU = @Parm01)
  BEGIN

    SET @c_PrintbySKU = 'Y'

  END


  IF @parm05 <> '1' AND EXISTS (SELECT 1 FROM SKU WITH (NOLOCK)
               WHERE SKU = SUBSTRING(@Parm01,3,13) )
  BEGIN

   SET @c_PrintbyIT69 = 'Y'

 END


  IF @c_PrintbyASN = 'Y'
  BEGIN
     SELECT DISTINCT PARM1 = RECEIPTDETAIL.RECEIPTKEY ,PARM2 = CASE WHEN ISNULL(RTRIM(@Parm02),'') <> '' THEN @Parm02 ELSE '' END ,PARM3= '',PARM4 = @Parm04,PARM5 = @Parm05,PARM6 ='',PARM7 = '' ,PARM8 = '',PARM9 = '',PARM10 = '',Key1 = 'ASN',Key2 = '',Key3 = '',Key4 = '',Key5 = ''  
     FROM  RECEIPTDETAIL RECEIPTDETAIL WITH (NOLOCK)    
     WHERE  RECEIPTDETAIL.receiptkey = @Parm01  
    -- AND  RECEIPTDETAIL.receiptlinenumber = CASE WHEN ISNULL(RTRIM(@Parm02),'') <> '' THEN @Parm02 ELSE RECEIPTDETAIL.receiptlinenumber END
  END
  ELSE IF  @c_PrintbySKU = 'Y'
  BEGIN
      SELECT PARM1 = @Parm01 ,PARM2 = @Parm02,PARM3= @Parm03,PARM4 = @Parm04,PARM5 = @Parm05,PARM6 ='',PARM7 = '' ,PARM8 = '',PARM9 = '',PARM10 = '',Key1 = 'SKU',Key2 = '',Key3 = '',Key4 = '',Key5 = ''
    END
  ELSE IF @c_PrintbyIT69 = 'Y'
  BEGIN

     IF CAST(@Parm02 as INT) >1500
   BEGIN
     GOTO EXIT_SP
   END

   SELECT DISTINCT PARM1 = LOTT.storerkey ,PARM2 = SUBSTRING(@Parm01,3,13),PARM3= SUBSTRING(@Parm01,1,2),PARM4 = @Parm02 ,PARM5 = Substring(LOTT.lottable02,1,12),
                   PARM6 =SUBSTRING(@Parm01,28,2),PARM7 = '' ,PARM8 = '',PARM9 = '',PARM10 = 'IT69',Key1 = 'IT69',Key2 = '',Key3 = '',Key4 = '',Key5 = ''
   FROM lotattribute LOTT WITH (NOLOCK)
   WHERE Substring(LOTT.lottable01,5,2) = SUBSTRING(@Parm01,1,2)
   AND LOTT.sku = SUBSTRING(@Parm01,3,13)
   AND Substring(LOTT.lottable02,1,12) =  SUBSTRING(@Parm01,16,12)
   AND Substring(LOTT.lottable02,14,2) = SUBSTRING(@Parm01,28,2)
   --AND LOTT.storerkey='18441'   --Remove storerkey restriction (Fy01)
  END


 --select * from #TEMP_PICKBYQTY


   EXIT_SP:

      SET @d_Trace_EndTime = GETDATE()
      SET @c_UserName = SUSER_SNAME()

   END -- procedure


GO