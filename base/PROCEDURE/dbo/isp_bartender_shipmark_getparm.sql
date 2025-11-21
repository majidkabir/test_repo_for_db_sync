SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Copyright: IDS                                                             */
/* Purpose: isp_Bartender_SHIPMARK_GetParm                                    */
/*                                                                            */
/* Modifications log:                                                         */
/*                                                                            */
/* Date       Rev  Author     Purposes                                        */
/* 2022-08-16 1.0  CSCHONG    Devops Scripts Combine & WMS-20494 Created      */
/* 2022-09-15 1.1  CSCHONG    WMS-20789 revised print logic (CS01)            */
/******************************************************************************/

CREATE PROC [dbo].[isp_Bartender_SHIPMARK_GetParm]
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
      @n_intFlag         INT,
      @n_CntRec          INT,
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
           @c_ExecStatements   NVARCHAR(4000),
           @c_ExecArguments    NVARCHAR(4000)

   SET @d_Trace_StartTime = GETDATE()
   SET @c_Trace_ModuleName = ''




        SELECT DISTINCT PARM1= PD.Pickslipno,PARM2=PD.Cartonno,PARM3= '' ,PARM4= '',PARM5='',PARM6='',PARM7='',
                        PARM8='',PARM9='',PARM10='',Key1='Pickslipno',Key2='Cartonno',Key3='',Key4='', Key5= ''
        --FROM PACKHEADER  PH WITH (NOLOCK)                                    --CS01 S
        --JOIN PACKDETAIL  PD WITH (NOLOCK) ON PD.PickSlipNo = PH.PickSlipNo
        FROM ORDERS ORD WITH (NOLOCK) 
        JOIN STORER ST WITH (NOLOCK) ON ST.storerkey = ORD.Storerkey
        JOIN PACKHEADER PH WITH (NOLOCK) ON PH.OrderKey = ORD.OrderKey
        JOIN PACKDETAIL PD WITH (NOLOCK) ON PD.Pickslipno = PH.Pickslipno 
        JOIN CODELKUP C WITH (NOLOCK) ON C.LISTNAME ='PECUSTNO' AND C.Storerkey=ORD.StorerKey AND C.code = ORD.ConsigneeKey   --CS01 E
        WHERE PH.Pickslipno = @Parm01 
        AND PD.CartonNo = CONVERT(INT,@Parm02) 


   EXIT_SP:

      SET @d_Trace_EndTime = GETDATE()
      SET @c_UserName = SUSER_SNAME()

   END -- procedure


GO