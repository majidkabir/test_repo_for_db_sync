SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/******************************************************************************/
/* Copyright: IDS                                                             */
/* Purpose: isp_Bartender_SKULABEL09_GetParm                                  */
/*                                                                            */
/* Modifications log:                                                         */
/*                                                                            */
/* Date       Rev  Author     Purposes                                        */
/* 2022-02-24 1.0  CSCHONG    Devops Scripts Combine & WMS-18945 (created)    */
/******************************************************************************/

CREATE PROC [dbo].[isp_Bartender_SKULABEL09_GetParm]
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
      @c_SQLOrdBy        NVARCHAR(150)


  DECLARE @d_Trace_StartTime   DATETIME,
           @d_Trace_EndTime    DATETIME,
           @c_Trace_ModuleName NVARCHAR(20),
           @d_Trace_Step1      DATETIME,
           @c_Trace_Step1      NVARCHAR(20),
           @c_UserName         NVARCHAR(20),
           @c_getUCCno         NVARCHAR(20),
           @c_getUdef09        NVARCHAR(30),
           @c_ExecStatements   NVARCHAR(4000),
           @c_ExecArguments    NVARCHAR(4000)

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


    SET @c_SQLOrdBy = 'ORDER BY S.Storerkey,S.SKU'

    SET @c_SQLJOIN = 'SELECT DISTINCT PARM1=S.Storerkey,PARM2=S.SKU,PARM3='''',PARM4='''',PARM5='''',PARM6='''',PARM7='''', '+
                     ' PARM8='''',PARM9='''',PARM10='''',Key1=''sku'',Key2='''',Key3='''',Key4='''','+
                      ' Key5= '''' '  +
                      ' FROM SKU S WITH (NOLOCK) '+
                      ' WHERE S.Storerkey =  RTRIM(@Parm01)  '


          IF EXISTS (SELECT 1 FROM SKU S WITH (NOLOCK) WHERE S.storerkey = @Parm01 AND S.Sku = RTRIM(@Parm02))
          BEGIN
             SET @c_condition1 = ' AND S.SKU = RTRIM(@Parm02)  '
          END
          ELSE IF EXISTS (SELECT 1 FROM SKU S WITH (NOLOCK) WHERE S.storerkey = @Parm01 AND S.altsku = RTRIM(@Parm02))
          BEGIN
              SET @c_condition1 = ' AND S.AltSKU = RTRIM(@Parm02)  '
           END
          ELSE IF ISNULL(@Parm01,'') <> '' AND ISNULL(@Parm02,'') <>''
          BEGIN IF EXISTS (SELECT 1 FROM SKU S WITH (NOLOCK) WHERE S.storerkey = @Parm01 AND S.MANUFACTURERSKU = RTRIM(@Parm02))
           BEGIN
              SET @c_condition1 = ' AND S.MANUFACTURERSKU = RTRIM(@Parm02)'
           END
       END

  --  select @c_condition1 '@c_condition1'
     IF ISNULL(@Parm01,'') = '' OR ISNULL(@Parm02,'') = ''
     BEGIN
      GOTO EXIT_SP
     END

     IF ISNULL(@c_condition1,'') = ''
     BEGIN
      GOTO EXIT_SP
     END
        SET @c_SQL = @c_SQLJOIN + @c_condition1 +CHAR(13)  + @c_SQLOrdBy
     -- PRINT @c_SQL

    --EXEC sp_executesql @c_SQL


   SET @c_ExecArguments = N'   @parm01           NVARCHAR(80)'
                          + ', @parm02           NVARCHAR(80) '
                          + ', @parm03           NVARCHAR(80) '


   EXEC sp_ExecuteSql     @c_SQL
                        , @c_ExecArguments
                        , @parm01
                        , @parm02
                        , @parm03

   EXIT_SP:

      SET @d_Trace_EndTime = GETDATE()
      SET @c_UserName = SUSER_SNAME()

   END -- procedure


GO