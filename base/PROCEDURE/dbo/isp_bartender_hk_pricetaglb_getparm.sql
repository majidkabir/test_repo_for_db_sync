SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Copyright: IDS                                                             */
/* Purpose: isp_Bartender_HK_PRICETAGLB_GetParm                              */
/*                                                                            */
/* Modifications log:                                                         */
/*                                                                            */
/* Date       Rev  Author     Purposes                                        */
/* 2019-06-21 1.0  WLCHOOI    Created - WMS-9506                              */
/******************************************************************************/

CREATE PROC [dbo].[isp_Bartender_HK_PRICETAGLB_GetParm]
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
      @c_ReceiptKey      NVARCHAR(10),
      @c_ExternOrderKey  NVARCHAR(10),
      @c_Deliverydate    DATETIME,
      @n_intFlag         INT,
      @n_CntRec          INT,
      @c_SQL             NVARCHAR(4000),
      @c_SQLSORT         NVARCHAR(4000),
      @c_SQLJOIN         NVARCHAR(4000),
      @c_condition1      NVARCHAR(150) ,
      @c_condition2      NVARCHAR(150),
      @c_SQLGroup        NVARCHAR(4000),
      @c_SQLOrdBy        NVARCHAR(150),
		@c_Getparm01       NVARCHAR(250),
		@c_Getparm02       NVARCHAR(250),
		@c_Getparm03       NVARCHAR(250),
      @c_Getparm04       NVARCHAR(250)   --INC0354249

  DECLARE @d_Trace_StartTime   DATETIME,
           @d_Trace_EndTime    DATETIME,
           @c_Trace_ModuleName NVARCHAR(20),
           @d_Trace_Step1      DATETIME,
           @c_Trace_Step1      NVARCHAR(20),
           @c_UserName         NVARCHAR(20),
           @n_cntsku           INT,
           @c_mode             NVARCHAR(1),
           @c_sku              NVARCHAR(20),
           @c_getUCCno         NVARCHAR(20),
           @c_getUdef09        NVARCHAR(30),
           @c_ExecStatements   NVARCHAR(4000),
           @c_ExecArguments    NVARCHAR(4000)

   SET @d_Trace_StartTime = GETDATE()
   SET @c_Trace_ModuleName = ''
	SET @c_Getparm01 = ''
	SET @c_Getparm02 = ''
	SET @c_Getparm03 = ''

    -- SET RowNo = 0
   SET @c_SQL = ''
   SET @c_mode = '0'
   SET @c_getUCCno = ''
   SET @c_getUdef09 = ''
   SET @c_SQLJOIN = ''
   SET @c_condition1 = ''
   SET @c_condition2= ''
   SET @c_SQLOrdBy = ''
   SET @c_SQLGroup = ''
   SET @c_ExecStatements = ''
   SET @c_ExecArguments = ''

   --If Barcode (Parm03) is blank, Parm04 must be blank
   IF ISNULL(@parm03,'') = ''
      SET @parm04 = ''
   
   --Check if it is SKU or ALTSKU, IF AltSku, find SKU
   IF(ISNULL(@parm03,'') <> '')
   BEGIN 
      IF NOT EXISTS (SELECT 1 FROM SKU (NOLOCK) WHERE SKU = @parm03 AND Storerkey = @Parm01)
      BEGIN
         IF EXISTS(SELECT 1 FROM SKU (NOLOCK) WHERE ALTSKU = @parm03 AND Storerkey = @Parm01)
         BEGIN
            SELECT @parm03 = SKU
            FROM SKU (NOLOCK) 
            WHERE ALTSKU = @parm03 AND Storerkey = @Parm01
         END
      END
   END

   SET @c_SQLJOIN = 'SELECT DISTINCT PARM1 = PD.Storerkey, PARM2 = PD.LabelNo, PARM3 = CASE WHEN ISNULL(@parm03,'''') = '''' THEN PD.SKU ELSE @parm03 END, ' +
                    ' PARM4 = CASE WHEN ISNULL(@parm04,'''') = '''' THEN SUM(PD.Qty) ELSE @parm04 END, PARM5 = '''', PARM6 = '''', PARM7 = '''', '+  
                    ' PARM8 = '''',PARM9 = '''',PARM10 = '''',Key1 = ''Storerkey'',Key2 = ''SKU'',Key3 = '''',' +  'Key4 = '''','+  ' Key5 = '''' '  +    
                    ' FROM PACKDETAIL PD WITH (NOLOCK) ' +
                    ' WHERE PD.LabelNo = @Parm02 ' +
                    ' AND PD.STORERKEY = @Parm01 ' +
                    ' AND PD.SKU = CASE WHEN ISNULL(@parm03,'''') = '''' THEN PD.SKU ELSE @parm03 END ' +
                    ' GROUP BY PD.STORERKEY, PD.LABELNO, PD.SKU '

PRINT @c_SQLJOIN
   SET @c_SQL = @c_SQLJOIN


    --EXEC sp_executesql @c_SQL

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

   END -- procedure



GO