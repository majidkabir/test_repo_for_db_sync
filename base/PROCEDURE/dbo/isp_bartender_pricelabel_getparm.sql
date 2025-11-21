SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Copyright: IDS                                                             */
/* Purpose: isp_Bartender_PRICELABEL_GetParm                                  */
/*                                                                            */
/* Modifications log:                                                         */
/*                                                                            */
/* Date       Rev  Author     Purposes                                        */
/* 2017-09-18 1.0  CSCHONG    WMS-3647                                        */
/* 2018-08-20 1.1  CHEEMUN    INC0354249 - Get Parm04 as Storerkey            */
/* 2018-09-05 1.2  LZG        INC0374541 & INC0354249 - Cater for both        */
/*                            issues (ZG01)                                   */
/******************************************************************************/

CREATE PROC [dbo].[isp_Bartender_PRICELABEL_GetParm]
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
      @c_ReceiptKey        NVARCHAR(10),
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

	 IF ISNULL(@parm01,'') = '' AND ISNULL(@parm02,'') = ''
	 BEGIN
	   GOTO EXIT_SP
	 END

	 SET @c_Getparm03 = @parm03
	 SET @c_Getparm04 = ISNULL(RTRIM(@parm04),'')                  -- ZG01

	 IF ISNULL(@parm01,'') <> ''
	 BEGIN

	  IF ISNULL(@parm02,'') <> ''
	  BEGIN
			 SELECT @c_Getparm01 = UCCNo
					 ,@c_Getparm02 = SKU
					 --,@c_Getparm04 = STORERKEY  --INC0354249
			 FROM UCC WITH (NOLOCK)
			 WHERE UCCNo = @parm01
			 AND SKU = @parm02

			 SET @c_condition1 = 'WHERE UCC.UCCNo = @c_Getparm01 AND UCC.SKU = @c_Getparm02'
			 SET @c_SQLOrdBy = ' ORDER BY UCC.SKU '

		 END
		 ELSE
		 BEGIN
			 SELECT @c_Getparm01 = UCCNo
			       --,@c_Getparm04 = STORERKEY  --INC0354249
			 FROM UCC WITH (NOLOCK)
			 WHERE UCCNo = @parm01

			 SET @c_condition1 = 'WHERE UCC.UCCNo = @c_Getparm01'

	 END


 END
 ELSE
 BEGIN

   SET @c_Getparm01 = ''

   SELECT @c_Getparm01 = MIN(UCCNo)
          ,@c_Getparm02 = @parm02
          --,@c_Getparm04 = STORERKEY  --INC0354249
			 FROM UCC WITH (NOLOCK)
     		 WHERE SKU = @parm02
          GROUP BY STORERKEY

   SET @c_condition1 = 'WHERE UCC.UCCNo = @c_Getparm01 AND UCC.SKU = @c_Getparm02'
 END

    IF ISNULL(@parm01,'') = ''
    BEGIN

    SET 	@c_Getparm01 = ''
    SET  @c_Getparm02 = @parm02

    SET @c_SQLJOIN = 'SELECT DISTINCT PARM1= @c_Getparm01,PARM2=@c_Getparm02,PARM3= @c_Getparm03 ,PARM4= @c_Getparm04,PARM5='''',PARM6='''',PARM7='''', '+  --INC0354249
                     'PARM8='''',PARM9='''',PARM10='''',Key1=''UCCNO'',Key2='''',Key3='''',' +
						   ' Key4='''' ,'+
							' Key5= '''' '
							--' FROM UCC WITH (NOLOCK) '

			SET @c_SQL = @c_SQLJOIN
    END
    ELSE
    BEGIN
    SET @c_SQLJOIN = 'SELECT DISTINCT PARM1= UCC.UCCno,PARM2=UCC.SKU,PARM3=@c_Getparm03 ,PARM4= @c_Getparm04,PARM5='''',PARM6='''',PARM7='''', '+     --INC0354249
                     'PARM8='''',PARM9='''',PARM10='''',Key1=''UCCNO'',Key2='''',Key3='''',' +
						   ' Key4='''' ,'+
							' Key5= '''' '  +
							' FROM UCC WITH (NOLOCK) '

			SET @c_SQL = @c_SQLJOIN + CHAR(13) +@c_condition1  + CHAR(13) + @c_SQLOrdBy
    END


    --EXEC sp_executesql @c_SQL

   SET @c_ExecArguments = N'   @c_Getparm01      NVARCHAR(80)'
                          + ', @c_Getparm02      NVARCHAR(80) '
                          + ', @c_Getparm03      NVARCHAR(80) '
                          + ', @c_Getparm04      NVARCHAR(80) '   --INC0354249


   EXEC sp_ExecuteSql     @c_SQL
                        , @c_ExecArguments
                        , @c_Getparm01
                        , @c_Getparm02
                        , @c_Getparm03
                        , @c_Getparm04    --INC0354249

   EXIT_SP:

      SET @d_Trace_EndTime = GETDATE()
      SET @c_UserName = SUSER_SNAME()

   END -- procedure



GO