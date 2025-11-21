SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Copyright: LFL                                                             */
/* Purpose: isp_Bartender_VASXDLBL01_GetParm                                  */
/*                                                                            */
/* Modifications log:                                                         */
/*                                                                            */
/* Date        Rev  Author     Purposes                                       */
/* 27-Mar-2023 1.0  WLChooi    Created (WMS-21983 & WMS-21984 & WMS-21985 &   */
/*                             WMS-21986)                                     */
/* 27-Mar-2023 1.0  WLChooi    DevOps Combine Script                          */
/******************************************************************************/

CREATE   PROC [dbo].[isp_Bartender_VASXDLBL01_GetParm]
(
   @c_parm01 NVARCHAR(250)
 , @c_parm02 NVARCHAR(250)
 , @c_parm03 NVARCHAR(250)
 , @c_parm04 NVARCHAR(250)
 , @c_parm05 NVARCHAR(250)
 , @c_parm06 NVARCHAR(250)
 , @c_parm07 NVARCHAR(250)
 , @c_parm08 NVARCHAR(250)
 , @c_parm09 NVARCHAR(250)
 , @c_parm10 NVARCHAR(250)
 , @b_debug  INT = 0
)
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_intFlag INT
         , @n_CntRec  INT
         , @c_SQL     NVARCHAR(4000)
         , @c_SQLSORT NVARCHAR(4000)
         , @c_SQLJOIN NVARCHAR(4000)

   DECLARE @d_Trace_StartTime  DATETIME
         , @d_Trace_EndTime    DATETIME
         , @c_Trace_ModuleName NVARCHAR(20)
         , @d_Trace_Step1      DATETIME
         , @c_Trace_Step1      NVARCHAR(20)
         , @c_UserName         NVARCHAR(20)
         , @c_BillToKey        NVARCHAR(50)
         , @c_Key3             NVARCHAR(30)
         , @c_Storerkey        NVARCHAR(15)

   SET @d_Trace_StartTime = GETDATE()
   SET @c_Trace_ModuleName = N''

   SELECT @c_BillToKey = OH.BillToKey
        , @c_Storerkey = OH.StorerKey
   FROM PACKDETAIL PD (NOLOCK)
   JOIN PACKHEADER PH (NOLOCK) ON PH.PickSlipNo = PD.PickSlipNo
   JOIN ORDERS OH (NOLOCK) ON OH.OrderKey = PH.OrderKey
   WHERE PD.StorerKey = CASE WHEN ISNULL(TRIM(@c_parm02), '') <> '' THEN @c_parm02
                             ELSE PD.StorerKey END 
   AND PD.LabelNo = @c_parm01

   IF EXISTS ( SELECT 1
               FROM CODELKUP CL (NOLOCK)
               WHERE CL.LISTNAME = 'FARMERVAS'
               AND CL.Code = @c_BillToKey
               AND CL.Storerkey = @c_Storerkey )
   BEGIN
      SET @c_Key3 = 'FARMER'
   END

   IF EXISTS ( SELECT 1
               FROM CODELKUP CL (NOLOCK)
               WHERE CL.LISTNAME = 'DJVAS'
               AND CL.Code = @c_BillToKey
               AND CL.Storerkey = @c_Storerkey )
   BEGIN
      SET @c_Key3 = 'DJ'
   END

   IF EXISTS ( SELECT 1
               FROM CODELKUP CL (NOLOCK)
               WHERE CL.LISTNAME = 'JJVAS'
               AND CL.Code = @c_BillToKey
               AND CL.Storerkey = @c_Storerkey )
   BEGIN
      SET @c_Key3 = 'JJ'
   END

   IF EXISTS ( SELECT 1
               FROM CODELKUP CL (NOLOCK)
               WHERE CL.LISTNAME = 'GLUEVAS'
               AND CL.Code = @c_BillToKey
               AND CL.Storerkey = @c_Storerkey )
   BEGIN
      SET @c_Key3 = 'GLUE'
   END

   IF @c_Key3 <> ''
   BEGIN
      SELECT DISTINCT PARM1 = PD.StorerKey
                    , PARM2 = PD.LabelNo
                    , PARM3 = ''
                    , PARM4 = ''
                    , PARM5 = ''
                    , PARM6 = ''
                    , PARM7 = ''
                    , PARM8 = ''
                    , PARM9 = ''
                    , PARM10 = ''
                    , Key1 = 'Storerkey'
                    , Key2 = 'LabelNo'
                    , Key3 = @c_Key3
                    , Key4 = ''
                    , Key5 = ''
      FROM PACKDETAIL PD (NOLOCK)
      WHERE PD.StorerKey = @c_Storerkey
      AND PD.LabelNo = @c_parm01
   END

   EXIT_SP:
END -- procedure

GO