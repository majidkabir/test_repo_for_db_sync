SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/********************************************************************************/
/* Copyright: MAERSK                                                            */
/* Purpose: isp_BT_Bartender_SG_UCCLBLSG02_AESOP                                */
/*                                                                              */
/* Modifications log:                                                           */
/*                                                                              */
/* Date        Rev  Author    Purposes                                          */
/* 11-May-2023 1.0  WLChooi   Created (WMS-22453)                               */
/* 11-May-2023 1.0  WLChooi   DevOps Combine Script                             */
/********************************************************************************/

CREATE   PROC [dbo].[isp_BT_Bartender_SG_UCCLBLSG02_AESOP]
(
   @c_Sparm01 NVARCHAR(250)
 , @c_Sparm02 NVARCHAR(250)
 , @c_Sparm03 NVARCHAR(250)
 , @c_Sparm04 NVARCHAR(250)
 , @c_Sparm05 NVARCHAR(250)
 , @c_Sparm06 NVARCHAR(250)
 , @c_Sparm07 NVARCHAR(250)
 , @c_Sparm08 NVARCHAR(250)
 , @c_Sparm09 NVARCHAR(250)
 , @c_Sparm10 NVARCHAR(250)
 , @b_debug   INT = 0
)
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF              

   DECLARE @n_intFlag        INT
         , @n_CntRec         INT
         , @c_SQL            NVARCHAR(4000)
         , @c_SQLSORT        NVARCHAR(4000)
         , @c_SQLJOIN        NVARCHAR(4000)
         , @c_ExecStatements NVARCHAR(4000)
         , @c_ExecArguments  NVARCHAR(4000)
         , @c_CheckConso     NVARCHAR(10)
         , @c_GetOrderkey    NVARCHAR(10)
         , @n_TTLpage        INT
         , @n_CurrentPage    INT
         , @n_MaxCtn         INT
         , @n_Casecnt        INT
         , @n_TotalCarton    INT
         , @c_LabelNo        NVARCHAR(30)
         , @c_Pickslipno     NVARCHAR(10)
         , @c_CartonNo       NVARCHAR(10)
         , @n_SumQty         INT
         , @c_Sorting        NVARCHAR(4000)
         , @c_ExtraSQL       NVARCHAR(4000)
         , @c_JoinStatement  NVARCHAR(4000)
         , @c_Confirmed      NVARCHAR(10) = 'N'
         , @c_Country        NVARCHAR(100)
         , @c_Zip            NVARCHAR(100)
         , @c_Col08          NVARCHAR(80) = ''
         , @c_DocType        NVARCHAR(10)

   DECLARE @d_Trace_StartTime  DATETIME
         , @d_Trace_EndTime    DATETIME
         , @c_Trace_ModuleName NVARCHAR(20)
         , @d_Trace_Step1      DATETIME
         , @c_Trace_Step1      NVARCHAR(20)
         , @c_UserName         NVARCHAR(20)              

   SET @d_Trace_StartTime = GETDATE()
   SET @c_Trace_ModuleName = N''

   SET @n_CurrentPage = 1
   SET @n_TTLpage = 1
   SET @n_CntRec = 1
   SET @n_intFlag = 1
   SET @c_ExtraSQL = N''
   SET @c_JoinStatement = N''

   SET @c_CheckConso = N'N'

   -- SET RowNo = 0               
   SET @c_SQL = N''

   --Discrete  
   SELECT TOP 1 @c_GetOrderkey = ORDERS.OrderKey
              , @c_Country = TRIM(ISNULL(ORDERS.C_Country,''))
              , @c_Zip = TRIM(ISNULL(ORDERS.C_Zip,''))
              , @c_DocType = ORDERS.DocType
   FROM PackHeader (NOLOCK)
   JOIN ORDERS (NOLOCK) ON ORDERS.OrderKey = PackHeader.OrderKey
   WHERE PackHeader.PickSlipNo = @c_Sparm01

   IF ISNULL(@c_GetOrderkey, '') = ''
   BEGIN
      --Conso  
      SELECT TOP 1 @c_GetOrderkey = ORDERS.OrderKey
                 , @c_Country = TRIM(ISNULL(ORDERS.C_Country,''))
                 , @c_Zip = TRIM(ISNULL(ORDERS.C_Zip,''))
                 , @c_DocType = ORDERS.DocType
      FROM PackHeader (NOLOCK)
      JOIN LoadPlanDetail (NOLOCK) ON PackHeader.LoadKey = LoadPlanDetail.LoadKey
      JOIN ORDERS (NOLOCK) ON ORDERS.OrderKey = LoadPlanDetail.OrderKey
      WHERE PackHeader.PickSlipNo = @c_Sparm01

      IF ISNULL(@c_GetOrderkey, '') <> ''
         SET @c_CheckConso = N'Y'
      ELSE
         GOTO EXIT_SP
   END

   IF @c_DocType <> 'E'
   BEGIN
      GOTO EXIT_SP
   END

   SELECT @c_Col08 = ISNULL(CL.Long,'')
   FROM CODELKUP CL WITH (NOLOCK) 
   WHERE CL.Listname = 'ISOCOUNTRY'
   AND CL.Code = @c_Country + @c_Zip

   SET @c_JoinStatement = N' JOIN ORDERS OH (NOLOCK) ON PH.ORDERKEY = OH.ORDERKEY ' + CHAR(13)

   IF @c_CheckConso = 'Y'
   BEGIN
      SET @c_JoinStatement = N' JOIN LOADPLANDETAIL LPD (NOLOCK) ON PH.LOADKEY = LPD.LOADKEY ' + CHAR(13)
                           + N' JOIN ORDERS OH (NOLOCK) ON OH.ORDERKEY = LPD.ORDERKEY ' + CHAR(13)
   END

   IF @b_debug = 1
      SELECT @c_CheckConso

   SELECT @c_Confirmed = CASE WHEN [Status] = '9' THEN 'Y' ELSE 'N' END
   FROM PACKHEADER (NOLOCK)
   WHERE Pickslipno = @c_Sparm01

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

   SET @c_Sorting = N' ORDER BY PH.Pickslipno ASC '

   SET @c_SQLJOIN = N' SELECT DISTINCT '''', OH.ExternOrderkey, TRIM(ISNULL(OH.C_Company,'''')), TRIM(ISNULL(OH.C_Contact1,'''')), '
                  + N' TRIM(ISNULL(OH.C_Address1,'''')), TRIM(ISNULL(OH.C_Address2,'''')), TRIM(ISNULL(OH.C_Address3,'''')), ' + CHAR(13) --7
                  + N' '''', PD.CartonNo, '''', ' + CHAR(13) --10   
                  + N' '''', TRIM(OH.Shipperkey), ' + CHAR(13)
                  + N' OH.TrackingNo, TRIM(ISNULL(OH.C_Address4,'''')), '''', ' + CHAR(13) --15
                  + N' '''', TRIM(ISNULL(OH.C_Contact1,'''')), TRIM(ISNULL(OH.C_Phone1,'''')), ' + CHAR(13) --18
                  + N' TRIM(ISNULL(OH.C_Phone2,'''')), '''', ' + CHAR(13) --20          
                  + N' '''', TRIM(ISNULL(ST.Company,'''')), TRIM(ISNULL(ST.Address1,'''')), TRIM(ISNULL(ST.Address2,'''')), ' + CHAR(13) --24
                  + N' TRIM(ISNULL(ST.Address3,'''')), TRIM(ISNULL(ST.Address4,'''')), '''', '''', '''', '''', ' + CHAR(13) --30     
                  + N' '''', '''', '''', '''', '''', '''', '''', '''', '''', '''', ' + CHAR(13) --40  
                  + N' '''', '''', '''', '''', '''', '''', '''', '''', '''', '''', ' + CHAR(13) --50        
                  + N' '''', '''', '''', '''', '''', '''', '''', '''', PH.Pickslipno, ''SG'' ' + CHAR(13) --60
                  + N' FROM PACKHEADER PH WITH (NOLOCK) ' + CHAR(13)
                  + N' JOIN PACKDETAIL PD WITH (NOLOCK) ON PD.Pickslipno = PH.Pickslipno ' + CHAR(13)
                  + N' JOIN STORER ST WITH (NOLOCK) ON ST.Storerkey = PH.Storerkey ' + CHAR(13)
                  + @c_JoinStatement 
                  + N' WHERE PH.Pickslipno = @c_Sparm01 ' + CHAR(13) 
                  + @c_Sorting

   IF @b_debug = 1
   BEGIN
      PRINT @c_SQLJOIN
   END

   SET @c_SQL = N'INSERT INTO #Result (Col01,Col02,Col03,Col04,Col05, Col06,Col07,Col08,Col09' + CHAR(13)
              + N'                    ,Col10,Col11,Col12,Col13,Col14,Col15,Col16,Col17,Col18,Col19,Col20,Col21,Col22' + CHAR(13)
              + N'                    ,Col23,Col24,Col25,Col26,Col27,Col28,Col29,Col30,Col31,Col32,Col33,Col34' + CHAR(13)
              + N'                    ,Col35,Col36,Col37,Col38,Col39,Col40,Col41,Col42,Col43,Col44' + CHAR(13)
              + N'                    ,Col45,Col46,Col47,Col48,Col49,Col50,Col51,Col52,Col53,Col54' + CHAR(13)
              + N'                    ,Col55,Col56,Col57,Col58,Col59,Col60) '

   SET @c_SQL = @c_SQL + @c_SQLJOIN

   --EXEC sp_executesql @c_SQL            

   SET @c_ExecArguments = N'  @c_Sparm01         NVARCHAR(80) ' 
                        + N', @c_Sparm02         NVARCHAR(80) '
                        + N', @c_Sparm03         NVARCHAR(80) '

   EXEC sp_executesql @c_SQL
                    , @c_ExecArguments
                    , @c_Sparm01
                    , @c_Sparm02
                    , @c_Sparm03

   IF @b_debug = 1
   BEGIN
      PRINT @c_SQL
   END

   SELECT @n_SumQty = SUM(Qty)
        , @n_MaxCtn = MAX(CartonNo)
   FROM PACKDETAIL (NOLOCK)
   WHERE Pickslipno = @c_Sparm01

   UPDATE #Result
   SET Col08 = ISNULL(@c_Col08,'')
     , Col10 = CASE WHEN @c_Confirmed = 'Y' THEN CAST(@n_MaxCtn AS NVARCHAR) ELSE 'XX' END
     , Col11 = @n_SumQty
   WHERE Col59 = @c_Sparm01

   RESULT:
   SELECT *
   FROM #Result (NOLOCK)
   ORDER BY ID

   EXIT_SP:

END -- procedure     

GO