SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/******************************************************************************/
/* Copyright: LFL                                                             */
/* Purpose: isp_BT_Bartender_JP_SHIPLBLSGW_BSJ                                */
/*                                                                            */
/* Modifications log:                                                         */
/*                                                                            */
/* Date        Rev  Author     Purposes                                       */
/* 10-Nov-2022 1.0  WLChooi    Created (WMS-21146)                            */
/* 10-Nov-2022 1.0  WLChooi    DevOps Combine Script                          */
/* 25-Jan-2023 1.1  BeeTin     JSM-124914 change hardcoded customer code      */
/* 30-Jan-2023 1.2  CHONGCS    WMS-21637 revised field mapping (CS01)         */
/* 24-Feb-2023 1.3  Mingle     WMS-21844 revised field mapping (ML01)         */
/* 05-JUL-2023 1.4  CHONGCS    WMS-22942 revised field mapping (CS02)         */
/******************************************************************************/

CREATE   PROC [dbo].[isp_BT_Bartender_JP_SHIPLBLSGW_BSJ] 
(
   @c_Sparm1  NVARCHAR(250)
 , @c_Sparm2  NVARCHAR(250)
 , @c_Sparm3  NVARCHAR(250)
 , @c_Sparm4  NVARCHAR(250)
 , @c_Sparm5  NVARCHAR(250)
 , @c_Sparm6  NVARCHAR(250)
 , @c_Sparm7  NVARCHAR(250)
 , @c_Sparm8  NVARCHAR(250)
 , @c_Sparm9  NVARCHAR(250)
 , @c_Sparm10 NVARCHAR(250)
 , @b_debug   INT = 0
)
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @c_ExecStatements NVARCHAR(MAX)
         , @c_ExecArguments  NVARCHAR(MAX)
         , @c_SQLJOIN        NVARCHAR(MAX)
         , @c_SQL            NVARCHAR(MAX)
         , @c_Condition      NVARCHAR(MAX)
         , @c_SQLJOINTable   NVARCHAR(MAX)
         , @c_SQLJOIN2       NVARCHAR(MAX)
         , @c_Orderkey       NVARCHAR(10)

   DECLARE @d_Trace_StartTime  DATETIME
         , @d_Trace_EndTime    DATETIME
         , @c_Trace_ModuleName NVARCHAR(20)
         , @d_Trace_Step1      DATETIME
         , @c_Trace_Step1      NVARCHAR(20)
         , @c_UserName         NVARCHAR(50)
         , @n_MaxCtn           INT
         , @c_Type             NVARCHAR(10)
         , @c_ClistUDF01       NVARCHAR(80) --CS01   

   SET @d_Trace_StartTime = GETDATE()
   SET @c_Trace_ModuleName = N''

   CREATE TABLE [#Result]
   (
      [ID]    [INT]          IDENTITY(1, 1) NOT NULL
    , [Col01] [NVARCHAR](80) NULL
    , [Col02] [NVARCHAR](80) NULL
    , [Col03] [NVARCHAR](80) NULL
    , [Col04] [NVARCHAR](80) NULL
    , [Col05] [NVARCHAR](80) NULL
    , [Col06] [NVARCHAR](80) NULL
    , [Col07] [NVARCHAR](80) NULL
    , [Col08] [NVARCHAR](80) NULL
    , [Col09] [NVARCHAR](80) NULL
    , [Col10] [NVARCHAR](80) NULL
    , [Col11] [NVARCHAR](80) NULL
    , [Col12] [NVARCHAR](80) NULL
    , [Col13] [NVARCHAR](80) NULL
    , [Col14] [NVARCHAR](80) NULL
    , [Col15] [NVARCHAR](80) NULL
    , [Col16] [NVARCHAR](80) NULL
    , [Col17] [NVARCHAR](80) NULL
    , [Col18] [NVARCHAR](80) NULL
    , [Col19] [NVARCHAR](80) NULL
    , [Col20] [NVARCHAR](80) NULL
    , [Col21] [NVARCHAR](80) NULL
    , [Col22] [NVARCHAR](80) NULL
    , [Col23] [NVARCHAR](80) NULL
    , [Col24] [NVARCHAR](80) NULL
    , [Col25] [NVARCHAR](80) NULL
    , [Col26] [NVARCHAR](80) NULL
    , [Col27] [NVARCHAR](80) NULL
    , [Col28] [NVARCHAR](80) NULL
    , [Col29] [NVARCHAR](80) NULL
    , [Col30] [NVARCHAR](80) NULL
    , [Col31] [NVARCHAR](80) NULL
    , [Col32] [NVARCHAR](80) NULL
    , [Col33] [NVARCHAR](80) NULL
    , [Col34] [NVARCHAR](80) NULL
    , [Col35] [NVARCHAR](80) NULL
    , [Col36] [NVARCHAR](80) NULL
    , [Col37] [NVARCHAR](80) NULL
    , [Col38] [NVARCHAR](80) NULL
    , [Col39] [NVARCHAR](80) NULL
    , [Col40] [NVARCHAR](80) NULL
    , [Col41] [NVARCHAR](80) NULL
    , [Col42] [NVARCHAR](80) NULL
    , [Col43] [NVARCHAR](80) NULL
    , [Col44] [NVARCHAR](80) NULL
    , [Col45] [NVARCHAR](80) NULL
    , [Col46] [NVARCHAR](80) NULL
    , [Col47] [NVARCHAR](80) NULL
    , [Col48] [NVARCHAR](80) NULL
    , [Col49] [NVARCHAR](80) NULL
    , [Col50] [NVARCHAR](80) NULL
    , [Col51] [NVARCHAR](80) NULL
    , [Col52] [NVARCHAR](80) NULL
    , [Col53] [NVARCHAR](80) NULL
    , [Col54] [NVARCHAR](80) NULL
    , [Col55] [NVARCHAR](80) NULL
    , [Col56] [NVARCHAR](80) NULL
    , [Col57] [NVARCHAR](80) NULL
    , [Col58] [NVARCHAR](80) NULL
    , [Col59] [NVARCHAR](80) NULL
    , [Col60] [NVARCHAR](80) NULL
   )

   SELECT @n_MaxCtn = MAX(PD.CartonNo)
   FROM PackDetail PD (NOLOCK)
   WHERE PD.PickSlipNo = @c_Sparm1

   SELECT @c_Orderkey = OrderKey
   FROM PackHeader (NOLOCK)
   WHERE PickSlipNo = @c_Sparm1

   --CS01 S  
   SELECT TOP 1 @c_ClistUDF01 = cl.UDF01
   FROM dbo.CODELIST cl WITH (NOLOCK)
   WHERE cl.LISTNAME = 'BSSGWSTR'

   --CS01 E   

   IF ISNULL(@c_Orderkey, '') = ''
   BEGIN
      SET @c_SQLJOINTable = N' JOIN LOADPLANDETAIL LPD (NOLOCK) ON LPD.Loadkey = PH.Loadkey ' + CHAR(13)
                            + N' JOIN ORDERS OH (NOLOCK) ON OH.Orderkey = LPD.Orderkey ' + CHAR(13)
                            + N' LEFT JOIN ORDERINFO OIF (NOLOCK) ON OIF.Orderkey = OH.Orderkey ' + CHAR(13)      --CS02
   END
   ELSE
   BEGIN
      SET @c_SQLJOINTable = N' JOIN ORDERS OH (NOLOCK) ON OH.Orderkey = PH.Orderkey ' + CHAR(13)
                          + N' LEFT JOIN ORDERINFO OIF (NOLOCK) ON OIF.Orderkey = OH.Orderkey ' + CHAR(13)      --CS02
   END

   SET @c_SQLJOIN = N' SELECT RIGHT(REPLICATE(''$'',4) + MAX(OH.DischargePlace),7) ' + CHAR(13) --ML01      
                    + N'      , N''発送日:'' + MAX(FORMAT(PH.EditDate, N''yy年MM月dd日'')) ' + CHAR(13)
                    + N'      , N''便種:'' + CASE WHEN MAX(OH.RDD)= ''O'' THEN  N''航空便'' ELSE N''陸便'' END ' + CHAR(13)  --CS02
                    + N'      , N''[配達指定]'' + FORMAT(MAX(OH.DeliveryDate), N''MM月dd日'') ' + CHAR(13)
                    + N'      , N''[時間帯指定] '' +  ' + CHAR(13)
                    + N'        CASE WHEN MAX(ISNULL(OH.UserDefine10,'''')) = ''''   THEN N''時間帯指定なし'' ' + CHAR(13)
                    + N'             WHEN MAX(ISNULL(OH.UserDefine10,'''')) = ''00'' THEN N''時間帯指定なし'' ' + CHAR(13)
                    + N'             WHEN MAX(ISNULL(OH.UserDefine10,'''')) = ''01'' THEN N''午前中'' ' + CHAR(13)
                    + N'             WHEN MAX(ISNULL(OH.UserDefine10,'''')) = ''12'' THEN N'''' ' + CHAR(13)
                    + N'             WHEN MAX(ISNULL(OH.UserDefine10,'''')) = ''14'' THEN N''12時 ~ 14時'' ' + CHAR(13)
                    + N'             WHEN MAX(ISNULL(OH.UserDefine10,'''')) = ''16'' THEN N''16時 ~ 18時'' ' + CHAR(13)
                    + N'             WHEN MAX(ISNULL(OH.UserDefine10,'''')) = ''18'' THEN N''18時 ~ 20時'' ' + CHAR(13)
                    + N'             WHEN MAX(ISNULL(OH.UserDefine10,'''')) = ''19'' THEN N''19時 ~ 21時'' ' + CHAR(13)
                    + N'             WHEN MAX(ISNULL(OH.UserDefine10,'''')) = ''04'' THEN N''18時 ~ 21時'' END '
                    + CHAR(13) + N'      , N''個数: '' + MAX(CAST(PH.TTLCNTS AS NVARCHAR)) ' + CHAR(13)
                    + N'      , CASE WHEN MAX(ISNULL(OH.DischargePlace,'''')) = '''' ' + CHAR(13)
                    + N'             THEN '''' ' + CHAR(13)
                    + N'             ELSE SUBSTRING(MAX(OH.DischargePlace), 1, LEN(MAX(OH.DischargePlace)) - 3) END ' + CHAR(13) --ML01      
                    + N'      , MAX(RIGHT(OH.DischargePlace,3)) ' + CHAR(13)
                    + N'      , N''〒'' + MAX(SUBSTRING(ISNULL(OH.C_Zip,''''),1,3)) + ''-'' + MAX(SUBSTRING(ISNULL(OH.C_Zip,''''),4,4)) '
                    + CHAR(13) + N'      , ''TEL'' + MAX(ISNULL(OH.C_Phone1,'''')) ' + CHAR(13)
                    + N'      , MAX(ISNULL(OH.C_Address1,'''')) ' + CHAR(13)
                    + N'      , MAX(ISNULL(OH.C_Address2,'''')) ' + CHAR(13)
                    + N'      , MAX(ISNULL(OH.C_Company,'''')) ' + CHAR(13)
                    + N'      , MAX(ISNULL(OH.C_contact1,'''')) ' + CHAR(13)
                    + N'      , MAX(ISNULL(OH.TrackingNo,'''')) ' + CHAR(13)
                    + N'      , N''お問い合せ送り状No:'' + MAX(ISNULL(OH.TrackingNo,'''')) ' + CHAR(13)
                    + N'      , MAX(ISNULL(OH.UserDefine01,'''')) ' + CHAR(13)
                    + N'      , ''TEL'' + MAX(ISNULL(OH.UserDefine02,'''')) ' + CHAR(13)
                    + N'      , MAX(TRIM(ISNULL(ST.B_State,''''))) + MAX(TRIM(ISNULL(ST.B_City,''''))) + MAX(TRIM(ISNULL(ST.B_Address1,''''))) '
                    + CHAR(13) + N'    , MAX(TRIM(ISNULL(ST.B_Address2,''''))) ' + CHAR(13)
                    + N'      , MAX(TRIM(ISNULL(ST.Company,''''))) ' + CHAR(13)
                    + N'      , MAX(TRIM(ISNULL(ST.Contact1,''''))) ' + CHAR(13)
                    + N'      , MAX(TRIM(ISNULL(ST.Zip,''''))) ' + CHAR(13)
                    + N'      , MAX(TRIM(ISNULL(ST.Phone1,''''))) ' + CHAR(13)
                    + N'      , CASE WHEN PD.CartonNo <> 1 THEN '''' ELSE N''〒'' + MAX(SUBSTRING(OH.C_Zip,1,3)) + ''-'' + MAX(SUBSTRING(OH.C_Zip,4,4)) END '
                    + CHAR(13)
                    + N'      , CASE WHEN PD.CartonNo <> 1 THEN '''' ELSE N''TEL'' + MAX(ISNULL(OH.C_Phone1,'''')) END '
                    + CHAR(13)
                    + N'      , CASE WHEN PD.CartonNo <> 1 THEN '''' ELSE MAX(ISNULL(OH.C_Address1,'''')) END '
                    + CHAR(13)
                    + N'      , CASE WHEN PD.CartonNo <> 1 THEN '''' ELSE MAX(ISNULL(OH.C_Address2,'''')) END '
                    + CHAR(13)
                    + N'      , CASE WHEN PD.CartonNo <> 1 THEN '''' ELSE MAX(ISNULL(OH.C_Company,'''')) END '
                    + CHAR(13)
                    + N'      , CASE WHEN PD.CartonNo <> 1 THEN '''' ELSE MAX(ISNULL(OH.C_contact1,'''')) END '
                    + CHAR(13)
                    + N'      , CASE WHEN PD.CartonNo <> 1 THEN '''' ELSE N''集荷 '' + MAX(ISNULL(OH.UserDefine01,'''')) END '
                    + CHAR(13)
                    + N'      , CASE WHEN PD.CartonNo <> 1 THEN '''' ELSE N''TEL '' + MAX(ISNULL(OH.UserDefine02,'''')) END '
                    + CHAR(13) + N'      , CASE WHEN PD.CartonNo <> 1  ' + CHAR(13)
                    + N'             THEN '''' ELSE MAX(TRIM(ISNULL(ST.B_State,''''))) + MAX(TRIM(ISNULL(ST.B_City,''''))) + MAX(TRIM(ISNULL(ST.B_Address1,''''))) END '
                    + CHAR(13)
                    + N'      , CASE WHEN PD.CartonNo <> 1 THEN '''' ELSE MAX(ISNULL(ST.B_Address2,'''')) END '
                    + CHAR(13)
                    + N'      , CASE WHEN PD.CartonNo <> 1 THEN '''' ELSE MAX(ISNULL(ST.B_Company,'''')) END '
                    + CHAR(13)
                    + N'      , CASE WHEN PD.CartonNo <> 1 THEN '''' ELSE MAX(ISNULL(ST.B_contact1,'''')) END '
                    + CHAR(13) + N'      , CASE WHEN PD.CartonNo <> 1 THEN '''' ELSE MAX(ISNULL(ST.B_Zip,'''')) END '
                    + CHAR(13)
                    + N'      , CASE WHEN PD.CartonNo <> 1 THEN '''' ELSE MAX(ISNULL(ST.B_Phone1,'''')) END '
                    + CHAR(13)
   --SET @c_SQLJOIN2 = N'     , N''お顧客コード 15359350000'' ' + CHAR(13)   --(JSM-124914)     --CS01  
   SET @c_SQLJOIN2 = N'      , N''お顧客コード '' + TRIM(ISNULL(@c_ClistUDF01,'''')) ' + CHAR(13) --Col39    --CS01  
                     --, N''お顧客コード 144788450113'' ' + CHAR(13)   --Col39      
                     + N'      , N''****************'' ' + CHAR(13) + N'      , N''*'' ' + CHAR(13)
                     + N'      , N''***************'' ' + CHAR(13) + N'      , N''********'' ' + CHAR(13)
                     + N'      , N''********'' ' + CHAR(13) + N'      , MAX(ISNULL(OIF.OrderInfo10,'''')) ' + CHAR(13) --Col45         --CS02
                     + N'      , N'''' ' + CHAR(13) + N'      , N'''' ' + CHAR(13) + N'      , N'''' ' + CHAR(13)
                     + N'      , MAX(ISNULL(OH.UserDefine01,'''')) ' + CHAR(13)
                     + N'      , N''TEL '' + MAX(ISNULL(OH.UserDefine02,'''')) ' + CHAR(13) --Col50      
                     + N'      , CASE WHEN PD.CartonNo <> 1 THEN '''' ELSE CASE WHEN MAX(OH.[Type]) = N''COD'' THEN N''830046'' ELSE N''830011'' END END '
                     + CHAR(13)
                     + N'      , CASE WHEN PD.CartonNo <> 1 THEN '''' ELSE MAX(ISNULL(OH.TrackingNo,'''')) END '
                     + CHAR(13)
                     -- + N'      , CASE WHEN PD.CartonNo <> 1 THEN N'''' ELSE N''144788450113'' END ' + CHAR(13)           
                     -- + N'      , CASE WHEN PD.CartonNo <> 1 THEN N'''' ELSE N''15359350000'' END ' + CHAR(13)      --(JSM-124914)  --CS01  
                     + N'      , CASE WHEN PD.CartonNo <> 1 THEN N'''' ELSE @c_ClistUDF01 END ' + CHAR(13) --CS01  
                     + N'      , CASE WHEN PD.CartonNo <> 1 THEN N''「この伝票は複数個口用です。」'' ELSE '''' END ' + CHAR(13)
                     + N'      , CASE WHEN PD.CartonNo = 1 THEN '''' ' + CHAR(13)
                     + N'             ELSE ''['' + CAST(PD.CartonNo AS NVARCHAR) + ''/'' + CAST(@n_MaxCtn AS NVARCHAR) + '']'' END '
                     + CHAR(13) --Col55      
                     + N'      , CASE WHEN PD.CartonNo <> 1 THEN '''' ELSE N''FAX '' + MAX(ISNULL(OH.UserDefine03,'''')) END '
                     + CHAR(13) + N'      , CASE WHEN PD.CartonNo <> 1 THEN N''********'' ELSE N'''' END '
                     + CHAR(13) --Col57      
                     + N'      ,CASE WHEN PD.CartonNo <> 1 THEN '''' ELSE N''納品書在中 '' END , MAX(ISNULL(OH.loadkey,'''')) + ''_'' + TRIM(@c_Sparm2), ''JP'' '
                     + N' FROM PACKDETAIL PD (NOLOCK) ' + CHAR(13)
                     + N' JOIN PACKHEADER PH (NOLOCK) ON PD.Pickslipno = PH.Pickslipno ' + CHAR(13)
                     + @c_SQLJOINTable
                     --+ N' LEFT JOIN PACKINFO PIF (NOLOCK) ON PIF.PickSlipNo = PD.PickSlipNo AND PIF.CartonNo = PD.CartonNo ' + CHAR(13)      
                     + N' JOIN STORER ST (NOLOCK) ON ST.StorerKey = OH.StorerKey  ' + CHAR(13)
                     + N' WHERE PD.Pickslipno = @c_Sparm1 AND PD.CartonNo = @c_Sparm2 ' + CHAR(13)
                     + N' GROUP BY PD.CartonNo '

   IF @b_debug = 1
   BEGIN
      PRINT @c_SQLJOIN
   END

   SET @c_SQL = N' INSERT INTO #Result (Col01,Col02,Col03,Col04,Col05, Col06,Col07,Col08,Col09' + CHAR(13)
                + N'                     ,Col10,Col11,Col12,Col13,Col14,Col15,Col16,Col17,Col18,Col19,Col20,Col21,Col22'
                + CHAR(13)
                + N'                     ,Col23,Col24,Col25,Col26,Col27,Col28,Col29,Col30,Col31,Col32,Col33,Col34'
                + CHAR(13) + N'                     ,Col35,Col36,Col37,Col38,Col39,Col40,Col41,Col42,Col43,Col44'
                + CHAR(13) + N'                     ,Col45,Col46,Col47,Col48,Col49,Col50,Col51,Col52,Col53,Col54'
                + CHAR(13) + N'                     ,Col55,Col56,Col57,Col58,Col59,Col60) '

   SET @c_SQL = @c_SQL + @c_SQLJOIN + @c_SQLJOIN2 + @c_Condition

   SET @c_ExecArguments = N'  @c_Sparm1         NVARCHAR(80)' + N' ,@c_Sparm2         NVARCHAR(80)'
                          + N' ,@c_Sparm3         NVARCHAR(80)' + N' ,@c_Sparm4         NVARCHAR(80)'
                          + N' ,@c_Sparm5         NVARCHAR(80)' + N' ,@n_MaxCtn         INT'
                          + N' ,@c_ClistUDF01     NVARCHAR(80)' --CS01  

   EXEC sp_executesql @c_SQL
                    , @c_ExecArguments
                    , @c_Sparm1
                    , @c_Sparm2
                    , @c_Sparm3
                    , @c_Sparm4
                    , @c_Sparm5
                    , @n_MaxCtn
                    , @c_ClistUDF01 --CS01  

   EXIT_SP:

   SET @d_Trace_EndTime = GETDATE()
   SET @c_UserName = SUSER_SNAME()

   SELECT *
   FROM #Result WITH (NOLOCK)

END -- procedure   

GO