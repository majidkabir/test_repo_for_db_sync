SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Copyright: LFL                                                             */
/* Purpose: isp_Bartender_OUTLBL_GetParm                                      */
/*                                                                            */
/* Modifications log:                                                         */
/*                                                                            */
/* Date       Rev  Author     Purposes                                        */
/* 2019-10-01 1.0  WLCHOOI    Created - WMS-10157 & 10308                     */
/******************************************************************************/

CREATE PROC [dbo].[isp_Bartender_OUTLBL_GetParm]
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
   SET CONCAT_NULL_YIELDS_NULL ON

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
      @c_Getparm04       NVARCHAR(250) 

  DECLARE @d_Trace_StartTime   DATETIME,
           @d_Trace_EndTime    DATETIME,
           @c_Trace_ModuleName NVARCHAR(20),
           @d_Trace_Step1      DATETIME,
           @c_Trace_Step1      NVARCHAR(20),
           @c_UserName         NVARCHAR(20),
           @n_RunningNo        INT = 1,
           @c_ExecStatements   NVARCHAR(4000),
           @c_ExecArguments    NVARCHAR(4000)

   SET @d_Trace_StartTime = GETDATE()
   SET @c_Trace_ModuleName = ''
   SET @c_Getparm01 = ''
   SET @c_Getparm02 = ''
   SET @c_Getparm03 = ''

    -- SET RowNo = 0
   SET @c_SQL = ''
   SET @c_SQLJOIN = ''
   SET @c_condition1 = ''
   SET @c_condition2= ''
   SET @c_SQLOrdBy = ''
   SET @c_SQLGroup = ''
   SET @c_ExecStatements = ''
   SET @c_ExecArguments = ''


   SET @c_SQLJOIN = N'SELECT DISTINCT PARM1 = LP.Loadkey, PARM2 = '''', PARM3 = '''' , ' +
                    ' PARM4 = '''', PARM5 = '''', PARM6 = '''', PARM7 = '''', '+  
                    ' PARM8 = '''',PARM9 = '''',PARM10 = '''',Key1 = ''Loadkey'',Key2 = '''',Key3 = '''',' +  'Key4 = '''','+  ' Key5 = '''' '  +    
                    ' FROM ORDERS OH WITH (NOLOCK) ' +
                    ' JOIN LOADPLANDETAIL LPD (NOLOCK) ON LPD.Orderkey = OH.Orderkey ' +
                    ' JOIN LOADPLAN LP (NOLOCK) ON LPD.Loadkey = LP.Loadkey ' +
                    ' WHERE LP.Loadkey = @parm01 ' 

   IF @b_debug = 1
   BEGIN 
      PRINT @c_SQLJOIN
   END

   SET @c_SQL = @c_SQLJOIN

    --EXEC sp_executesql @c_SQL

   SET @c_ExecArguments = N'  @parm01           NVARCHAR(80) '      
                          +', @parm02           NVARCHAR(80) '  
                                        
   EXEC sp_ExecuteSql     @c_SQL       
                        , @c_ExecArguments      
                        , @parm01      
                        , @parm02  

   EXIT_SP:

      SET @d_Trace_EndTime = GETDATE()
      SET @c_UserName = SUSER_SNAME()

   END -- procedure


GO