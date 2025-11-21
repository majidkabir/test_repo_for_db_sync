SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/******************************************************************************/
/* Copyright: IDS                                                             */
/* Purpose: isp_Bartender_CN_NKESHIPLBL_GetParm                               */
/*                                                                            */
/* Modifications log:                                                         */
/*                                                                            */
/* Date       Rev  Author     Purposes                                        */
/* 2022-06-29 1.0  CSCHONG    DevOps Scripts Combine & Created(WMS-20089)     */
/******************************************************************************/

CREATE PROC [dbo].[isp_Bartender_CN_NKESHIPLBL_GetParm]
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

   CREATE TABLE #TEMPORDERS (
      RowID          INT IDENTITY (1,1) NOT NULL ,
      storerkey      NVARCHAR(20),
      Loadkey        NVARCHAR(30) ,
      Orderkey       NVARCHAR(30) )

   --IF ISNULL(@parm02,'')  <> ''
 --   BEGIN
   --   INSERT INTO #TEMPORDERS (storerkey,Loadkey,Orderkey,Qty)
   --   SELECT OH.Storerkey,OH.loadkey,OH.Orderkey,SUM(PD.Qty)
   --   FROM ORDERS OH WITH (NOLOCK)
   -- --  JOIN PICKDETAIL PD (NOLOCK) ON OH.OrderKey=PD.OrderKey
   --   WHERE OH.Loadkey = @parm01
   --   AND OH.Orderkey = @parm02
   --   GROUP BY OH.Storerkey,OH.loadkey,OH.Orderkey
 --   END
   --ELSE
   --BEGIN
     INSERT INTO #TEMPORDERS (storerkey,Loadkey,Orderkey)
      SELECT OH.Storerkey,OH.loadkey,OH.Orderkey
      FROM ORDERS OH WITH (NOLOCK)
     -- JOIN PICKDETAIL PD (NOLOCK) ON OH.OrderKey=PD.OrderKey
      WHERE OH.Loadkey = @parm01
      --AND OH.Orderkey = @parm02
      GROUP BY OH.Storerkey,OH.loadkey,OH.Orderkey
   --END


        SELECT DISTINCT PARM1= loadkey,PARM2=OrderKey,PARM3= '',PARM4= '',PARM5='',PARM6='',PARM7='',
                PARM8='',PARM9='',PARM10='',Key1='LoadKey',Key2='orderkey',Key3='',Key4='', Key5= '' 
                 FROM  #TEMPORDERS P WITH (NOLOCK) 
                 WHERE LoadKey =  @parm01    

   DROP TABLE #TEMPORDERS

   EXIT_SP:

      SET @d_Trace_EndTime = GETDATE()
      SET @c_UserName = SUSER_SNAME()

   END -- procedure


GO