SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/******************************************************************************/
/* Copyright: LFL                                                             */
/* Purpose: isp_Bartender_SG_UCCLBLSG05_GetParm                               */
/*                                                                            */
/* Modifications log:                                                         */
/*                                                                            */
/* Date       Rev  Author     Purposes                                        */
/* 2023-07-10 1.0  WLChooi    Created - DevOps Combine Script (WMS-23038)     */
/******************************************************************************/

CREATE   PROC [dbo].[isp_Bartender_SG_UCCLBLSG05_GetParm]
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

   DECLARE @d_Trace_StartTime  DATETIME,
           @d_Trace_EndTime    DATETIME,
           @c_Trace_ModuleName NVARCHAR(20),
           @d_Trace_Step1      DATETIME,
           @c_Trace_Step1      NVARCHAR(20),
           @c_UserName         NVARCHAR(20),
           @c_ExecStatements   NVARCHAR(4000),
           @c_ExecArguments    NVARCHAR(4000),
           @n_maxCtn           INT

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

   SELECT @n_MaxCtn = MAX(CartonNo)  
   FROM PACKDETAIL (NOLOCK)  
   WHERE Pickslipno = @Parm01 

 SELECT DISTINCT    PARM1 = PD.Pickslipno, 
                    PARM2 = PD.CartonNo, 
                    PARM3 = @n_MaxCtn,
                    PARM4 = ISNULL(@Parm04,''), 
                    PARM5 = ISNULL(@Parm05,''), 
                    PARM6 = ISNULL(@Parm06,''), 
                    PARM7 = ISNULL(@Parm07,''), 
                    PARM8 = ISNULL(@Parm08,''), 
                    PARM9 = ISNULL(@Parm09,''), 
                    PARM10 = ISNULL(@Parm10,''), 
                    Key1 = '', 
                    Key2 = '', 
                    Key3 = '',         
                    Key4 = '',          
                    Key5 = ''          
                    FROM PACKHEADER PH WITH (NOLOCK) 
                    JOIN PACKDETAIL PD WITH (NOLOCK) ON PD.PickSlipNo = PH.PickSlipNo
                    WHERE PH.Pickslipno = @Parm01 
                    ORDER BY PD.Pickslipno,PD.CartonNo 


EXIT_SP:

END -- procedure

GO