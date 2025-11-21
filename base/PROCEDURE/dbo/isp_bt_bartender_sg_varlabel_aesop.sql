SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/********************************************************************************/
/* Copyright: LFL                                                               */
/* Purpose: isp_BT_Bartender_SG_VARLABEL_AESOP                                  */
/*                                                                              */
/* Modifications log:                                                           */
/*                                                                              */
/* Date       Rev  Author     Purposes                                          */
/* 2023-05-05 1.0  CSCHONG    Created (WMS-22411)                               */
/* 2023-05-08 1.0  CSCHONG    DevOps Combine Script                             */
/********************************************************************************/

CREATE   PROC [dbo].[isp_BT_Bartender_SG_VARLABEL_AESOP]
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

   DECLARE @n_intFlag            INT,
           @n_CntRec             INT,
           @c_SQL                NVARCHAR(4000),
           @c_SQLSORT            NVARCHAR(4000),
           @c_SQLJOIN            NVARCHAR(4000),
           @c_ExecStatements     NVARCHAR(4000),
           @c_ExecArguments      NVARCHAR(4000),

           @n_TTLpage            INT,
           @n_CurrentPage        INT,
           @n_MaxLine            INT,
           @n_Continue           INT,
           @c_DataCol            NVARCHAR(50),
           @c_Storerkey          NVARCHAR(15),
           @c_JoinStatement      NVARCHAR(4000)

   DECLARE @c_SKU01              NVARCHAR(80),
           @c_SKU02              NVARCHAR(80),
           @c_SKU03              NVARCHAR(80),
           @c_SKU04              NVARCHAR(80),
           @c_SKU05              NVARCHAR(80),
           @c_SKU06              NVARCHAR(80),
           @c_SKU07              NVARCHAR(80),
           @c_SKU_DESCR01        NVARCHAR(80),
           @c_SKU_DESCR02        NVARCHAR(80),
           @c_SKU_DESCR03        NVARCHAR(80),
           @c_SKU_DESCR04        NVARCHAR(80),
           @c_SKU_DESCR05        NVARCHAR(80),
           @c_SKU_DESCR06        NVARCHAR(80),
           @c_SKU_DESCR07        NVARCHAR(80),
           @c_SKU_PQty01         NVARCHAR(10),
           @c_SKU_PQty02         NVARCHAR(10),
           @c_SKU_PQty03         NVARCHAR(10),
           @c_SKU_PQty04         NVARCHAR(10),
           @c_SKU_PQty05         NVARCHAR(10),
           @c_SKU_PQty06         NVARCHAR(10),
           @c_SKU_PQty07         NVARCHAR(10),
           @c_SKU_CQty01         NVARCHAR(10),
           @c_SKU_CQty02         NVARCHAR(10),
           @c_SKU_CQty03         NVARCHAR(10),
           @c_SKU_CQty04         NVARCHAR(10),
           @c_SKU_CQty05         NVARCHAR(10),
           @c_SKU_CQty06         NVARCHAR(10),
           @c_SKU_CQty07         NVARCHAR(10),

           @c_SKU                NVARCHAR(80),
           @c_SKU_DESCR          NVARCHAR(80),
           @n_SKU_PQty           INT,
           @n_SKU_CQty           INT,
           @n_Total_PQty         INT,
           @n_Total_CQty         INT

   SET @n_CurrentPage = 1
   SET @n_TTLpage = 1
   SET @n_MaxLine = 4
   SET @n_CntRec = 1
   SET @n_intFlag = 1
   SET @c_JoinStatement = ''
   SET @c_SQL = ''
   SET @n_Continue = 1

   --Only discrete
   CREATE TABLE #TMP_Orderkey (
      Orderkey    NVARCHAR(10)
    , EditDate    NVARCHAR(20)
    , UserName    NVARCHAR(250)
    , Label       NVARCHAR(20)
   )

   CREATE TABLE [#TEMPSKU] (
      [ID]          [INT] IDENTITY(1,1) NOT NULL,
      [DataCol]     [NVARCHAR] (50) NULL,
      [SKU]         [NVARCHAR] (20) NULL,
      [SKUDESCR]    [NVARCHAR] (80) NULL,
      [PQty]        [INT],   --ExpectedQty
      [CQty]        [INT],   --ScannedQty
      [Retrieve]    [NVARCHAR] (1) DEFAULT 'N')

   INSERT INTO #TMP_Orderkey(Orderkey, EditDate, UserName, Label)
   SELECT MAX(PH.Orderkey)
        , MAX(CONVERT(NVARCHAR(6), R.EditDate, 103)) + RIGHT(MAX(CONVERT(NVARCHAR(10), R.EditDate, 103)), 2) + ' ' +
          MAX(CONVERT(NVARCHAR(8), R.EditDate, 114))
        , MAX(R.UserName), 'Carton No'
   FROM PACKDETAIL PD (NOLOCK)
   JOIN PACKHEADER PH (NOLOCK) ON PD.PickSlipNo = PH.PickSlipNo
   JOIN RDT.RDTPPA R (NOLOCK) ON PD.DropID = R.DropID AND PD.StorerKey = R.Storerkey
   WHERE PD.DropID = @c_Sparm01 AND PD.StorerKey = @c_Sparm02

   IF EXISTS (SELECT 1 FROM CODELKUP CL (NOLOCK)
              WHERE CL.LISTNAME = 'REPORTCFG'
              AND CL.Code = 'ShowOnlyVar'
              AND CL.Long = 'RDTPPA'
              AND CL.Short = 'Y')
   BEGIN

      INSERT INTO #TEMPSKU (DataCol, SKU, SKUDESCR, PQty, CQty, Retrieve)
      SELECT PD.DropID, PD.SKU, SKU.Descr, PD.Qty, ISNULL(R.CQty,0), 'N'
      FROM PackDetail PD (NOLOCK)
      JOIN SKU ON SKU.StorerKey = PD.StorerKey AND SKU.Sku = PD.SKU
      LEFT JOIN RDT.RDTPPA R (NOLOCK) ON PD.STORERKEY = R.STORERKEY AND PD.DROPID = R.DROPID AND PD.SKU = R.SKU
      WHERE PD.DropID = @c_Sparm01
      AND PD.Storerkey = @c_Sparm02
      AND PD.Qty <> ISNULL(R.CQty,0)
   END
   ELSE
   BEGIN

      INSERT INTO #TEMPSKU (DataCol, SKU, SKUDESCR, PQty, CQty, Retrieve)
      SELECT PD.DropID, PD.SKU, SKU.Descr, PD.Qty, IsNull(R.CQty,0), 'N'
      FROM PackDetail PD (NOLOCK)
      JOIN SKU ON SKU.StorerKey = PD.StorerKey AND SKU.Sku = PD.SKU
      LEFT JOIN RDT.RDTPPA R (NOLOCK) ON PD.STORERKEY = R.STORERKEY AND PD.DROPID = R.DROPID AND PD.SKU = R.SKU
      WHERE PD.DropID = @c_Sparm01
      AND PD.Storerkey = @c_Sparm02
   END

   --In RDTPPA but not in Packdetail
   INSERT INTO #TEMPSKU (DataCol, SKU, SKUDESCR, PQty, CQty, Retrieve)
   SELECT R.DropID, R.SKU, SKU.Descr, 0, R.CQty, 'N'
   FROM RDT.RDTPPA R (NOLOCK)
   JOIN SKU ON SKU.StorerKey = R.StorerKey AND SKU.Sku = R.SKU
   WHERE R.DropID = @c_Sparm01
   AND R.Storerkey = @c_Sparm02
   AND R.CQty > 0
   AND NOT EXISTS (SELECT 1 FROM PackDetail PD (NOLOCK) WHERE PD.StorerKey = R.StorerKey AND PD.DropID = R.DropID AND PD.SKU = R.Sku)

   IF NOT EXISTS (SELECT 1 FROM #TMP_Orderkey)
   BEGIN
      INSERT INTO #TMP_Orderkey(Orderkey, EditDate, UserName, Label)
      SELECT PH.OrderKey, MAX(CONVERT(NVARCHAR(10), R.EditDate, 103)), MAX(R.UserName), 'Pickslip No'
      FROM PACKHEADER PH (NOLOCK)
      JOIN PACKDETAIL PD (NOLOCK) ON PD.PickSlipNo = PH.PickSlipNo
      JOIN RDT.RDTPPA R (NOLOCK) ON PD.DropID = R.DropID AND PD.StorerKey = R.Storerkey
      WHERE PH.PickSlipNo = @c_Sparm01
      GROUP BY PH.OrderKey

      IF NOT EXISTS (SELECT 1 FROM #TEMPSKU)
      BEGIN
         IF EXISTS (SELECT 1 FROM CODELKUP CL (NOLOCK)
                    WHERE CL.LISTNAME = 'REPORTCFG'
                    AND CL.Code = 'ShowOnlyVar'
                    AND CL.Long = 'RDTPPA'
                    AND CL.Short = 'Y')
         BEGIN


            INSERT INTO #TEMPSKU (DataCol, SKU, SKUDESCR, PQty, CQty, Retrieve)
            SELECT PD.Pickslipno, PD.SKU, SKU.Descr, SUM(PD.Qty)
                 , (SELECT ISNULL(SUM(R.CQTY),0)
                    FROM RDT.RDTPPA R (NOLOCK)
                    WHERE R.STORERKEY = PD.STORERKEY AND R.Pickslipno = PD.Pickslipno AND R.SKU = PD.SKU)
                 ,'N'
            FROM PackDetail PD (NOLOCK)
            JOIN SKU ON SKU.StorerKey = PD.StorerKey AND SKU.Sku = PD.SKU
            WHERE PD.Pickslipno = @c_Sparm01
            AND PD.Storerkey = @c_Sparm02
            GROUP BY PD.STORERKEY, PD.Pickslipno, PD.SKU, SKU.Descr

            DELETE FROM #TEMPSKU
            WHERE PQty = CQty
         END
         ELSE
         BEGIN


            INSERT INTO #TEMPSKU (DataCol, SKU, SKUDESCR, PQty, CQty, Retrieve)
            SELECT PD.Pickslipno, PD.SKU, SKU.Descr, SUM(PD.Qty)
                , (SELECT ISNULL(SUM(R.CQTY),0)
                   FROM RDT.RDTPPA R (NOLOCK)
                   WHERE R.STORERKEY = PD.STORERKEY AND R.Pickslipno = PD.Pickslipno AND R.SKU = PD.SKU)
                ,'N'
            FROM PackDetail PD (NOLOCK)
            JOIN SKU ON SKU.StorerKey = PD.StorerKey AND SKU.Sku = PD.SKU
            WHERE PD.Pickslipno = @c_Sparm01
            AND PD.Storerkey = @c_Sparm02
            GROUP BY PD.STORERKEY, PD.Pickslipno, PD.SKU, SKU.Descr
         END

         --In RDTPPA but not in Packdetail
         INSERT INTO #TEMPSKU (DataCol, SKU, SKUDESCR, PQty, CQty, Retrieve)
         SELECT R.Pickslipno, R.SKU, SKU.Descr, 0, R.CQty, 'N'
         FROM RDT.RDTPPA R (NOLOCK)
         JOIN SKU ON SKU.StorerKey = R.StorerKey AND SKU.Sku = R.SKU
         WHERE R.Pickslipno = @c_Sparm01
         AND R.Storerkey = @c_Sparm02
         AND R.CQty > 0
         AND NOT EXISTS (SELECT 1 FROM PackDetail PD (NOLOCK) WHERE PD.StorerKey = R.StorerKey AND PD.Pickslipno = R.Pickslipno AND PD.SKU = R.Sku)
      END
   END

   IF NOT EXISTS (SELECT 1 FROM #TMP_Orderkey)
   BEGIN
      INSERT INTO #TMP_Orderkey(Orderkey, EditDate, UserName, Label)
      SELECT MAX(R.Orderkey), MAX(CONVERT(NVARCHAR(10), R.EditDate, 103)), MAX(R.UserName), 'Pallet ID'
      FROM RDT.RDTPPA R (NOLOCK)
      WHERE R.ID = @c_Sparm01 AND R.StorerKey = @c_Sparm02

      IF NOT EXISTS (SELECT 1 FROM #TEMPSKU)
      BEGIN
         IF EXISTS (SELECT 1 FROM CODELKUP CL (NOLOCK)
                    WHERE CL.LISTNAME = 'REPORTCFG'
                    AND CL.Code = 'ShowOnlyVar'
                    AND CL.Long = 'RDTPPA'
                    AND CL.Short = 'Y')
         BEGIN


            INSERT INTO #TEMPSKU (DataCol, SKU, SKUDESCR, PQty, CQty, Retrieve)
            SELECT PD.PalletKey, PD.SKU, SKU.Descr, SUM(PD.Qty)
                 , (SELECT ISNULL(SUM(R.CQTY),0)
                    FROM RDT.RDTPPA R (NOLOCK)
                    WHERE R.STORERKEY = PD.STORERKEY AND R.ID = PD.PalletKey AND R.SKU = PD.SKU)
                 ,'N'
            FROM PalletDetail PD (NOLOCK)
            JOIN SKU ON SKU.StorerKey = PD.StorerKey AND SKU.Sku = PD.SKU
            WHERE PD.PalletKey = @c_Sparm01
            AND PD.Storerkey = @c_Sparm02
            GROUP BY PD.STORERKEY, PD.PalletKey, PD.SKU, SKU.Descr

            DELETE FROM #TEMPSKU
            WHERE PQty = CQty
         END
         ELSE
         BEGIN

            INSERT INTO #TEMPSKU (DataCol, SKU, SKUDESCR, PQty, CQty, Retrieve)
            SELECT PD.PalletKey, PD.SKU, SKU.Descr, SUM(PD.Qty)
                , (SELECT ISNULL(SUM(R.CQTY),0)
                   FROM RDT.RDTPPA R (NOLOCK)
                   WHERE R.STORERKEY = PD.STORERKEY AND R.ID = PD.PalletKey AND R.SKU = PD.SKU)
                ,'N'
            FROM PalletDetail PD (NOLOCK)
            JOIN SKU ON SKU.StorerKey = PD.StorerKey AND SKU.Sku = PD.SKU
            WHERE PD.PalletKey = @c_Sparm01
            AND PD.Storerkey = @c_Sparm02
            GROUP BY PD.STORERKEY, PD.PalletKey, PD.SKU, SKU.Descr
         END

         --In RDTPPA but not in Palletdetail
         INSERT INTO #TEMPSKU (DataCol, SKU, SKUDESCR, PQty, CQty, Retrieve)
         SELECT R.ID, R.SKU, SKU.Descr, 0, R.CQty, 'N'
         FROM RDT.RDTPPA R (NOLOCK)
         JOIN SKU ON SKU.StorerKey = R.StorerKey AND SKU.Sku = R.SKU
         WHERE R.ID = @c_Sparm01
         AND R.Storerkey = @c_Sparm02
         AND R.CQty > 0
         AND NOT EXISTS (SELECT 1 FROM PalletDetail PD (NOLOCK) WHERE PD.StorerKey = R.StorerKey AND PD.PalletKey = R.ID AND PD.SKU = R.Sku)
      END
   END

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

   SET @c_SQLJOIN = + ' SELECT DISTINCT ORD.Orderkey, ORD.EditDate, ORD.UserName, '''', '''', ' + CHAR(13) --5
                    + ' '''', '''', '''', '''', '''', ' + CHAR(13) --10
                    + ' '''', '''', '''', '''', '''', '''', '''', '''', '''', '''', '  + CHAR(13) --20
                    + ' '''', '''', '''', '''', '''', '''', '''', '''', '''', '''', '  + CHAR(13) --30
                    + ' '''', '''', '''', ORD.Label, @c_Sparm01, '''', '''', '''', '''', '''', '  + CHAR(13) --40
                    + ' '''', '''', '''', '''', '''', '''', '''', '''', '''', '''', '  + CHAR(13) --50
                    + ' '''', '''', '''', '''', '''', '''', '''', '''', R.Storerkey, ''SG'' '  --60
                    + CHAR(13) +
                    + ' FROM PACKHEADER PH WITH (NOLOCK)'   + CHAR(13)
                    + ' JOIN PACKDETAIL PD WITH (NOLOCK) ON PH.Pickslipno = PD.Pickslipno'   + CHAR(13)
                    + ' JOIN RDT.RDTPPA R (NOLOCK) ON R.Storerkey = PD.StorerKey AND R.DropID = PD.DropID'   + CHAR(13)
                    + ' JOIN #TMP_Orderkey ORD WITH (NOLOCK) ON ORD.Orderkey = PH.Orderkey'   + CHAR(13)

   IF @b_debug=1
   BEGIN
      PRINT @c_SQLJOIN
   END

   SET @c_SQL='INSERT INTO #Result (Col01,Col02,Col03,Col04,Col05, Col06,Col07,Col08,Col09' + CHAR(13) +
             +',Col10,Col11,Col12,Col13,Col14,Col15,Col16,Col17,Col18,Col19,Col20,Col21,Col22' + CHAR(13) +
             +',Col23,Col24,Col25,Col26,Col27,Col28,Col29,Col30,Col31,Col32,Col33,Col34' + CHAR(13) +
             +',Col35,Col36,Col37,Col38,Col39,Col40,Col41,Col42,Col43,Col44' + CHAR(13) +
             +',Col45,Col46,Col47,Col48,Col49,Col50,Col51,Col52,Col53,Col54' + CHAR(13) +
             +',Col55,Col56,Col57,Col58,Col59,Col60) '

   SET @c_SQL = @c_SQL + @c_SQLJOIN

   SET @c_ExecArguments = N' @c_Sparm01         NVARCHAR(80) '
                        + ', @c_Sparm02         NVARCHAR(80) '
                        + ', @c_Sparm03         NVARCHAR(80) '

   EXEC sp_ExecuteSql  @c_SQL
                     , @c_ExecArguments
                     , @c_Sparm01
                     , @c_Sparm02
                     , @c_Sparm03

   IF @b_debug=1
   BEGIN
      PRINT @c_SQL
   END

   IF @n_Continue IN (1,2)
   BEGIN
      DECLARE CUR_RowNoLoop CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT DISTINCT Col35
      FROM #Result

      OPEN CUR_RowNoLoop

      FETCH NEXT FROM CUR_RowNoLoop INTO @c_DataCol

      WHILE @@FETCH_STATUS <> -1
      BEGIN
         SET @c_SKU01       = ''
         SET @c_SKU02       = ''
         SET @c_SKU03       = ''
         SET @c_SKU04       = ''
         SET @c_SKU05       = ''
         SET @c_SKU06       = ''
         SET @c_SKU07       = ''
         SET @c_SKU_DESCR01 = ''
         SET @c_SKU_DESCR02 = ''
         SET @c_SKU_DESCR03 = ''
         SET @c_SKU_DESCR04 = ''
         SET @c_SKU_DESCR05 = ''
         SET @c_SKU_DESCR06 = ''
         SET @c_SKU_DESCR07 = ''
         SET @c_SKU_PQty01  = ''
         SET @c_SKU_PQty02  = ''
         SET @c_SKU_PQty03  = ''
         SET @c_SKU_PQty04  = ''
         SET @c_SKU_PQty05  = ''
         SET @c_SKU_PQty06  = ''
         SET @c_SKU_PQty07  = ''
         SET @c_SKU_CQty01  = ''
         SET @c_SKU_CQty02  = ''
         SET @c_SKU_CQty03  = ''
         SET @c_SKU_CQty04  = ''
         SET @c_SKU_CQty05  = ''
         SET @c_SKU_CQty06  = ''
         SET @c_SKU_CQty07  = ''

         SELECT @n_CntRec = COUNT (1)
         FROM #TEMPSKU
         WHERE DataCol = @c_DataCol
         AND Retrieve = 'N'

         SET @n_TTLpage =  FLOOR(@n_CntRec / @n_MaxLine ) + CASE WHEN @n_CntRec % @n_MaxLine > 0 THEN 1 ELSE 0 END

         WHILE @n_intFlag <= @n_CntRec
         BEGIN
            IF @n_intFlag > @n_MaxLine AND (@n_intFlag % @n_MaxLine) = 1 --AND @c_LastRec = 'N'
            BEGIN
               SET @n_CurrentPage = @n_CurrentPage + 1

               IF (@n_CurrentPage > @n_TTLpage)
               BEGIN
                  BREAK;
               END

               INSERT INTO #Result (Col01,Col02,Col03,Col04,Col05, Col06,Col07,Col08,Col09
                                   ,Col10,Col11,Col12,Col13,Col14,Col15,Col16,Col17,Col18,Col19,Col20,Col21,Col22
                                   ,Col23,Col24,Col25,Col26,Col27,Col28,Col29,Col30,Col31,Col32,Col33,Col34
                                   ,Col35,Col36,Col37,Col38,Col39,Col40,Col41,Col42,Col43,Col44
                                   ,Col45,Col46,Col47,Col48,Col49,Col50,Col51,Col52,Col53,Col54
                                   ,Col55,Col56,Col57,Col58,Col59,Col60)
               SELECT TOP 1 Col01,Col02,Col03,'','','','','','','',
                            '','','','','','','','','','',
                            '','','','','','','','','','',
                            '','','',Col34,Col35,'','','','','',
                            '','','','','','','','','','',
                            '','','','','','','','',Col59,Col60
               FROM #Result

               SET @c_SKU01       = ''
               SET @c_SKU02       = ''
               SET @c_SKU03       = ''
               SET @c_SKU04       = ''
               SET @c_SKU05       = ''
               SET @c_SKU06       = ''
               SET @c_SKU07       = ''
               SET @c_SKU_DESCR01 = ''
               SET @c_SKU_DESCR02 = ''
               SET @c_SKU_DESCR03 = ''
               SET @c_SKU_DESCR04 = ''
               SET @c_SKU_PQty01  = ''
               SET @c_SKU_PQty02  = ''
               SET @c_SKU_PQty03  = ''
               SET @c_SKU_PQty04  = ''
               SET @c_SKU_CQty01  = ''
               SET @c_SKU_CQty02  = ''
               SET @c_SKU_CQty03  = ''
               SET @c_SKU_CQty04  = ''

            END

            SELECT @c_SKU       = T.SKU
                 , @c_SKU_DESCR = T.SKUDESCR
                 , @n_SKU_PQty  = SUM(T.PQty)
                 , @n_SKU_CQty  = SUM(T.CQty)
            FROM #TEMPSKU T
            WHERE ID = @n_intFlag
            GROUP BY T.SKU, T.SKUDESCR

            IF (@n_intFlag % @n_MaxLine) = 1
            BEGIN
              SET @c_SKU01 = @c_SKU
              SET @c_SKU_DESCR01 = @c_SKU_DESCR
              SET @c_SKU_PQty01 = CONVERT(NVARCHAR(10),@n_SKU_PQty)
              SET @c_SKU_CQty01 = CONVERT(NVARCHAR(10),@n_SKU_CQty)
            END
            ELSE IF (@n_intFlag % @n_MaxLine) = 2
            BEGIN
              SET @c_SKU02 = @c_SKU
              SET @c_SKU_DESCR02 = @c_SKU_DESCR
              SET @c_SKU_PQty02 = CONVERT(NVARCHAR(10),@n_SKU_PQty)
              SET @c_SKU_CQty02 = CONVERT(NVARCHAR(10),@n_SKU_CQty)
            END
            ELSE IF (@n_intFlag % @n_MaxLine) = 3
            BEGIN
              SET @c_SKU03 = @c_SKU
              SET @c_SKU_DESCR03 = @c_SKU_DESCR
              SET @c_SKU_PQty03 = CONVERT(NVARCHAR(10),@n_SKU_PQty)
              SET @c_SKU_CQty03 = CONVERT(NVARCHAR(10),@n_SKU_CQty)
            END
            ELSE IF (@n_intFlag % @n_MaxLine) = 0
            BEGIN
              SET @c_SKU04 = @c_SKU
              SET @c_SKU_DESCR04 = @c_SKU_DESCR
              SET @c_SKU_PQty04 = CONVERT(NVARCHAR(10),@n_SKU_PQty)
              SET @c_SKU_CQty04 = CONVERT(NVARCHAR(10),@n_SKU_CQty)
            END


            UPDATE #Result
            SET Col04 = @c_SKU01
              , Col05 = @c_SKU_DESCR01
              , Col06 = @c_SKU_PQty01
              , Col07 = @c_SKU_CQty01
              , Col08 = @c_SKU02
              , Col09 = @c_SKU_DESCR02
              , Col10 = @c_SKU_PQty02
              , Col11 = @c_SKU_CQty02
              , Col12 = @c_SKU03
              , Col13 = @c_SKU_DESCR03
              , Col14 = @c_SKU_PQty03
              , Col15 = @c_SKU_CQty03
              , Col16 = @c_SKU04
              , Col17 = @c_SKU_DESCR04
              , Col18 = @c_SKU_PQty04
              , Col19 = @c_SKU_CQty04
              , Col36 = CAST(@n_CurrentPage AS NVARCHAR(80))
            WHERE ID = @n_CurrentPage

            UPDATE #TEMPSKU
            SET Retrieve ='Y'
            WHERE ID = @n_intFlag

            SET @n_intFlag = @n_intFlag + 1

            IF @n_intFlag > @n_CntRec
            BEGIN
               BREAK;
            END
         END

         FETCH NEXT FROM CUR_RowNoLoop INTO @c_DataCol
      END -- While
      CLOSE CUR_RowNoLoop
      DEALLOCATE CUR_RowNoLoop

      SELECT @n_Total_PQty = SUM(T.PQty)
           , @n_Total_CQty = SUM(T.CQty)
      FROM #TEMPSKU T

      UPDATE #Result
      SET Col32 = CAST(@n_Total_PQty AS NVARCHAR(80))
        , Col33 = CAST(@n_Total_CQty AS NVARCHAR(80))
      WHERE Col35 = @c_Sparm01
   END

EXIT_SP:
   SELECT * FROM #Result (nolock)
   ORDER BY ID

   IF OBJECT_ID('tempdb..#TEMPSKU') IS NOT NULL
      DROP TABLE #TEMPSKU

   IF OBJECT_ID('tempdb..#Result') IS NOT NULL
      DROP TABLE #Result

END -- procedure

GO