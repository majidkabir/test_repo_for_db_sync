SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/********************************************************************************/
/* Copyright: LFL                                                               */
/* Purpose: isp_BT_Bartender_CN_SHIPUCCLBL_LAGARDERE                            */
/*                                                                              */
/* Modifications log:                                                           */
/*                                                                              */
/* Date       Rev  Author     Purposes                                          */
/* 2021-12-14 1.0  WLChooi    Created (WMS-18563)                               */
/* 2021-12-14 1.1  WLChooi    DevOps Combine Script                             */
/* 2022-07-08 1.2  CSCHONG    WMS-20176 revised field logic (CS01)              */
/********************************************************************************/

CREATE PROC [dbo].[isp_BT_Bartender_CN_SHIPUCCLBL_LAGARDERE]
(  @c_Sparm01            NVARCHAR(250),
   @c_Sparm02            NVARCHAR(250),
   @c_Sparm03            NVARCHAR(250),
   @c_Sparm04            NVARCHAR(250),
   @c_Sparm05            NVARCHAR(250),
   @c_Sparm06            NVARCHAR(250),
   @c_Sparm07            NVARCHAR(250),
   @c_Sparm08            NVARCHAR(250),
   @c_Sparm09            NVARCHAR(250),
   @c_Sparm10            NVARCHAR(250),
   @b_debug              INT = 0
)
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   --SET ANSI_WARNINGS OFF

   DECLARE
      @c_ReceiptKey      NVARCHAR(10),
      @n_intFlag         INT,
      @n_CntRec          INT,
      @c_SQL             NVARCHAR(4000),
      @c_SQLSORT         NVARCHAR(4000),
      @c_SQLJOIN         NVARCHAR(4000),
      @c_ExecStatements  NVARCHAR(4000),
      @c_ExecArguments   NVARCHAR(4000),

      @c_CheckConso      NVARCHAR(10),
      @c_GetOrderkey     NVARCHAR(10),

      @n_TTLpage         INT,
      @n_CurrentPage     INT,
      @n_MaxLine         INT,

      @c_LabelNo            NVARCHAR(30),
      @c_Pickslipno         NVARCHAR(10),
      @c_CartonNo           NVARCHAR(10),
      @n_SumQty             INT,
      @n_MaxCtn             INT,
      @c_Sorting            NVARCHAR(4000),
      @c_ExtraSQL           NVARCHAR(4000),
      @c_JoinStatement      NVARCHAR(4000),
      @c_AllExtOrderkey     NVARCHAR(80) = '',
      @c_Col01              NVARCHAR(80) = '',
      @c_Storerkey          NVARCHAR(15) = '',
      @c_Sbusr6             NVARCHAR(30) = ''         --CS01
   

   SET @n_CurrentPage = 1
   SET @n_TTLpage = 1
   SET @n_MaxLine = 10
   SET @n_CntRec = 1
   SET @n_intFlag = 1
   SET @c_ExtraSQL = ''
   SET @c_JoinStatement = ''

   SET @c_CheckConso = 'N'
   SET @c_SQL = ''

   --Discrete
   SELECT TOP 1 @c_GetOrderkey = ORDERS.Orderkey,
               -- @c_Col01       = ISNULL(ORDERS.UserDefine01,''),    --CS01
                @c_Storerkey   = ORDERS.Storerkey
   FROM PACKHEADER (NOLOCK)
   JOIN ORDERS (NOLOCK) ON ORDERS.ORDERKEY = PACKHEADER.ORDERKEY
   WHERE PACKHEADER.Pickslipno = @c_Sparm01


   --CS01 S
     SELECT DISTINCT TOP 1 @c_Sbusr6 = ISNULL(S.BUSR6,'')
     FROM PACKHEADER (NOLOCK)
     JOIN ORDERS (NOLOCK) ON ORDERS.ORDERKEY = PACKHEADER.ORDERKEY
     JOIN ORDERDETAIL OD WITH (NOLOCK) ON OD.OrderKey = ORDERS.Orderkey
     JOIN SKU S WITH (NOLOCK) ON s.StorerKey=OD.StorerKey AND S.sku = OD.Sku 
     WHERE PACKHEADER.Pickslipno = @c_Sparm01

   --CS01 E

   IF ISNULL(@c_GetOrderkey,'') = ''
   BEGIN
      --Conso
      SELECT TOP 1 @c_GetOrderkey = ORDERS.Orderkey,
                 --  @c_Col01       = ISNULL(ORDERS.UserDefine01,''),    --CS01
                   @c_Storerkey   = ORDERS.Storerkey
      FROM PACKHEADER (NOLOCK)
      JOIN LOADPLANDETAIL (NOLOCK) ON PACKHEADER.LOADKEY = LOADPLANDETAIL.LOADKEY
      JOIN ORDERS (NOLOCK) ON ORDERS.ORDERKEY = LOADPLANDETAIL.ORDERKEY
      WHERE PACKHEADER.Pickslipno = @c_Sparm01


      IF ISNULL(@c_GetOrderkey,'') <> ''
         SET @c_CheckConso = 'Y'
      ELSE
         GOTO EXIT_SP


      --CS01 S
        SELECT DISTINCT TOP 1 @c_Sbusr6 = ISNULL(S.BUSR6,'')
        FROM PACKHEADER (NOLOCK)
        JOIN LOADPLANDETAIL (NOLOCK) ON PACKHEADER.LOADKEY = LOADPLANDETAIL.LOADKEY
        JOIN ORDERS (NOLOCK) ON ORDERS.ORDERKEY = LOADPLANDETAIL.ORDERKEY
        JOIN ORDERDETAIL OD WITH (NOLOCK) ON OD.OrderKey = ORDERS.Orderkey
        JOIN SKU S WITH (NOLOCK) ON s.StorerKey=OD.StorerKey AND S.sku = OD.Sku
        WHERE PACKHEADER.Pickslipno = @c_Sparm01
      --CS01 E

   END

    --CS01 S
    IF ISNULL(@c_Sbusr6,'') <> ''
    BEGIN
       SET @c_Col01 = @c_Sbusr6
    END
    ELSE
    BEGIN
     SET @c_Col01 = ''
    END
    --CS01 E


   SET @c_JoinStatement = N' JOIN ORDERS OH (NOLOCK) ON PH.ORDERKEY = OH.ORDERKEY ' + CHAR(13)

   IF @c_CheckConso = 'Y'
   BEGIN
      SET @c_JoinStatement = N' JOIN LOADPLANDETAIL LPD (NOLOCK) ON PH.LOADKEY = LPD.LOADKEY ' + CHAR(13)
                            + ' JOIN ORDERS OH (NOLOCK) ON OH.ORDERKEY = LPD.ORDERKEY ' + CHAR(13)
   END

   IF @c_CheckConso = 'Y'
   BEGIN
      SELECT @c_AllExtOrderkey = CAST(STUFF((SELECT DISTINCT TOP 5 ',' + RTRIM(OH.ExternOrderkey)
                                 FROM PACKHEADER PH (NOLOCK)
                                 JOIN LOADPLANDETAIL LPD (NOLOCK) ON LPD.LoadKey = PH.LoadKey
                                 JOIN ORDERS OH (NOLOCK) ON OH.OrderKey = LPD.OrderKey
                                 WHERE PH.PickSlipNo = @c_Sparm01
                                 ORDER BY ',' + RTRIM(OH.ExternOrderkey) FOR XML PATH('')),1,1,'' ) AS NVARCHAR(80))
   END
   ELSE
   BEGIN
      SELECT @c_AllExtOrderkey = MAX(OH.ExternOrderkey)
      FROM PACKHEADER PH (NOLOCK)
      JOIN ORDERS OH (NOLOCK) ON OH.OrderKey = PH.Orderkey
      WHERE PH.PickSlipNo = @c_Sparm01
   END

   SELECT @c_Col01 = LEFT(TRIM(@c_Col01), 80)
   SELECT @c_AllExtOrderkey = LEFT(TRIM(@c_AllExtOrderkey), 80)

   IF @b_debug = 1
      SELECT @c_CheckConso

   CREATE TABLE [#Result] (
      [ID]    [INT] IDENTITY(1,1) NOT NULL,
      [Col01] [NVARCHAR] (80) NULL,
      [Col02] [NVARCHAR] (80) NULL,
      [Col03] [NVARCHAR] (80) NULL,
      [Col04] [NVARCHAR] (80) NULL,
      [Col05] [NVARCHAR] (80) NULL,
      [Col06] [NVARCHAR] (80) NULL,
      [Col07] [NVARCHAR] (80) NULL,
      [Col08] [NVARCHAR] (80) NULL,
      [Col09] [NVARCHAR] (80) NULL,
      [Col10] [NVARCHAR] (80) NULL,
      [Col11] [NVARCHAR] (80) NULL,
      [Col12] [NVARCHAR] (80) NULL,
      [Col13] [NVARCHAR] (80) NULL,
      [Col14] [NVARCHAR] (80) NULL,
      [Col15] [NVARCHAR] (80) NULL,
      [Col16] [NVARCHAR] (80) NULL,
      [Col17] [NVARCHAR] (80) NULL,
      [Col18] [NVARCHAR] (80) NULL,
      [Col19] [NVARCHAR] (80) NULL,
      [Col20] [NVARCHAR] (80) NULL,
      [Col21] [NVARCHAR] (80) NULL,
      [Col22] [NVARCHAR] (80) NULL,
      [Col23] [NVARCHAR] (80) NULL,
      [Col24] [NVARCHAR] (80) NULL,
      [Col25] [NVARCHAR] (80) NULL,
      [Col26] [NVARCHAR] (80) NULL,
      [Col27] [NVARCHAR] (80) NULL,
      [Col28] [NVARCHAR] (80) NULL,
      [Col29] [NVARCHAR] (80) NULL,
      [Col30] [NVARCHAR] (80) NULL,
      [Col31] [NVARCHAR] (80) NULL,
      [Col32] [NVARCHAR] (80) NULL,
      [Col33] [NVARCHAR] (80) NULL,
      [Col34] [NVARCHAR] (80) NULL,
      [Col35] [NVARCHAR] (80) NULL,
      [Col36] [NVARCHAR] (80) NULL,
      [Col37] [NVARCHAR] (80) NULL,
      [Col38] [NVARCHAR] (80) NULL,
      [Col39] [NVARCHAR] (80) NULL,
      [Col40] [NVARCHAR] (80) NULL,
      [Col41] [NVARCHAR] (80) NULL,
      [Col42] [NVARCHAR] (80) NULL,
      [Col43] [NVARCHAR] (80) NULL,
      [Col44] [NVARCHAR] (80) NULL,
      [Col45] [NVARCHAR] (80) NULL,
      [Col46] [NVARCHAR] (80) NULL,
      [Col47] [NVARCHAR] (80) NULL,
      [Col48] [NVARCHAR] (80) NULL,
      [Col49] [NVARCHAR] (80) NULL,
      [Col50] [NVARCHAR] (80) NULL,
      [Col51] [NVARCHAR] (80) NULL,
      [Col52] [NVARCHAR] (80) NULL,
      [Col53] [NVARCHAR] (80) NULL,
      [Col54] [NVARCHAR] (80) NULL,
      [Col55] [NVARCHAR] (80) NULL,
      [Col56] [NVARCHAR] (80) NULL,
      [Col57] [NVARCHAR] (80) NULL,
      [Col58] [NVARCHAR] (80) NULL,
      [Col59] [NVARCHAR] (80) NULL,
      [Col60] [NVARCHAR] (80) NULL
     )

      CREATE TABLE #Temp_Packdetail (
       [ID]              [INT] IDENTITY(1,1) NOT NULL,
       [Pickslipno]      [NVARCHAR] (80) NULL,
       [LabelNo]         [NVARCHAR] (80) NULL,
       [CartonNo]        [NVARCHAR] (80) NULL,
       [LabelLine]       [NVARCHAR] (80) NULL,
       [SKU]             [NVARCHAR] (80) NULL,
       [Size]            [NVARCHAR] (80) NULL,
       [Qty]             [NVARCHAR] (80) NULL,
       [Retreive]        [NVARCHAR] (80) NULL
      )

      SET @c_Sorting = N' ORDER BY PH.Pickslipno, PD.CartonNo DESC '

      SET @c_SQLJOIN = + ' SELECT DISTINCT @c_Col01, OH.Loadkey, @c_AllExtOrderkey, PH.Pickslipno, ISNULL(ST.Contact2,''''), ' + CHAR(13) --5
                       + ' ISNULL(ST.Address2,''''), PD.LabelNo ,'''' ,PD.CartonNo ,'''' , ' + CHAR(13) --10
                       + ' '''' ,'''' ,'''' ,'''' ,'''' ,'''' ,'''' ,'''' ,'''' ,'''' , ' + CHAR(13) --20
                       + ' '''' ,'''' ,'''' ,'''' ,'''' ,'''' ,'''' ,'''' ,'''' ,'''' , ' + CHAR(13) --30
                       + ' '''' ,'''' ,'''' ,'''' ,'''' ,'''' ,'''' ,'''' ,'''' ,'''' ,'  + CHAR(13) --40
                       + ' '''' ,'''' ,'''' ,'''' ,'''' ,'''' ,'''' ,'''' ,'''' ,'''' , ' + CHAR(13) --50
                       + ' '''' ,'''' ,'''' ,'''' ,'''' ,'''' ,'''' ,'''' ,PH.Pickslipno ,''CN'' ' + CHAR(13) --60
                       + ' FROM PACKHEADER PH WITH (NOLOCK)'        + CHAR(13)
                       + ' JOIN PACKDETAIL PD WITH (NOLOCK) ON PH.Pickslipno = PD.Pickslipno'   + CHAR(13)
                       +   @c_JoinStatement
                     --  + ' LEFT JOIN STORER ST WITH (NOLOCK) ON ST.STORERKEY = OH.Consigneekey ' + CHAR(13)     --CS01
                       + ' LEFT JOIN STORER ST WITH (NOLOCK) ON ST.Address1 = OH.C_Address1 AND ST.consigneefor = ''Lagardere'' ' + CHAR(13)     --CS01
                       + ' WHERE PH.Pickslipno = @c_Sparm01 '   + CHAR(13)
                       + ' AND PD.CartonNo BETWEEN CAST(@c_Sparm02 AS INT) AND CAST(@c_Sparm03 AS INT) ' + CHAR(13)
                       + ' GROUP BY OH.Loadkey, PH.Pickslipno, ISNULL(ST.Contact2,'''') ' + CHAR(13)
                       + '        , ISNULL(ST.Address2,''''), PD.LabelNo, PD.CartonNo ' + CHAR(13)
                       + @c_Sorting
   IF @b_debug=1
   BEGIN
      PRINT @c_SQLJOIN
   END

   SET @c_SQL='INSERT INTO #Result (Col01,Col02,Col03,Col04,Col05, Col06,Col07,Col08,Col09'  + CHAR(13) +
             +',Col10,Col11,Col12,Col13,Col14,Col15,Col16,Col17,Col18,Col19,Col20,Col21,Col22'  + CHAR(13) +
             +',Col23,Col24,Col25,Col26,Col27,Col28,Col29,Col30,Col31,Col32,Col33,Col34' + CHAR(13) +
             +',Col35,Col36,Col37,Col38,Col39,Col40,Col41,Col42,Col43,Col44'  + CHAR(13) +
             +',Col45,Col46,Col47,Col48,Col49,Col50,Col51,Col52,Col53,Col54'+ CHAR(13) +
             +',Col55,Col56,Col57,Col58,Col59,Col60) '

   SET @c_SQL = @c_SQL + @c_SQLJOIN

   SET @c_ExecArguments =    N'  @c_Sparm01         NVARCHAR(80) '
                            + ', @c_Sparm02         NVARCHAR(80) '
                            + ', @c_Sparm03         NVARCHAR(80) '
                            + ', @c_AllExtOrderkey  NVARCHAR(80) '
                            + ', @c_Col01           NVARCHAR(80) '

   EXEC sp_ExecuteSql     @c_SQL
                        , @c_ExecArguments
                        , @c_Sparm01
                        , @c_Sparm02
                        , @c_Sparm03
                        , @c_AllExtOrderkey
                        , @c_Col01

   IF @b_debug=1
   BEGIN
      PRINT @c_SQL
   END

   SELECT @n_SumQty = SUM(PD.Qty)
   FROM PACKDETAIL PD (NOLOCK)
   WHERE PD.PickSlipNo = @c_Sparm01
   AND PD.CartonNo BETWEEN CAST(@c_Sparm02 AS INT) AND CAST(@c_Sparm03 AS INT)

   SELECT @n_MaxCtn = MAX(PD.CartonNo)
   FROM PACKDETAIL PD (NOLOCK)
   WHERE PD.PickSlipNo = @c_Sparm01

   UPDATE #Result
   SET Col08 = @n_SumQty
     , Col10 = @n_MaxCtn
   WHERE Col59 = @c_Sparm01

RESULT:
   SELECT * FROM #Result (nolock)
   ORDER BY ID

EXIT_SP:

END -- procedure

GO