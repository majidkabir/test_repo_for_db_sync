SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Copyright: IDS                                                             */
/* Purpose: isp_BT_Bartender_SHIPLBLLVS_01                                    */
/*                                                                            */
/* Modifications log:                                                         */
/*                                                                            */
/* Date        Rev  Author     Purposes                                       */
/* 18-JAN-2029 1.0  CSCHONG   Created (WMS-16067)                             */
/* 02-Feb-2023 1.1  WLChooi   WMS-21683 Add Col45, modify table linkage (WL01)*/
/* 27-Feb-2023 1.2  WLChooi   WMS-21683 Modify sorting (WL02)                 */
/* 27-JUL-2023 1.3  CSCHONG   Devops Scripts Combine & WMS-22904 (CS01)       */
/******************************************************************************/

CREATE   PROC [dbo].[isp_BT_Bartender_SHIPLBLLVS_01]
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

   DECLARE @c_LoadKey   NVARCHAR(10)
         , @c_sku       NVARCHAR(80)
         , @n_ExtOrdRow INT
         , @n_intFlag   INT
         , @n_CntRec    INT
         , @c_SQL       NVARCHAR(4000)
         , @c_SQLSORT   NVARCHAR(4000)
         , @c_SQLJOIN   NVARCHAR(4000)
         , @c_col58     NVARCHAR(10)
         , @c_labelline NVARCHAR(10)
         , @n_CartonNo  INT

   DECLARE @d_Trace_StartTime  DATETIME
         , @d_Trace_EndTime    DATETIME
         , @c_Trace_ModuleName NVARCHAR(20)
         , @d_Trace_Step1      DATETIME
         , @c_Trace_Step1      NVARCHAR(20)
         , @c_UserName         NVARCHAR(20)
         , @c_SSIZE01          NVARCHAR(10)
         , @c_SSIZE02          NVARCHAR(10)
         , @c_SSIZE03          NVARCHAR(10)
         , @c_SSIZE04          NVARCHAR(10)
         , @c_SSIZE05          NVARCHAR(10)
         , @c_SSIZE06          NVARCHAR(10)
         , @c_SSIZE07          NVARCHAR(10)
         , @c_SSIZE08          NVARCHAR(10)
         , @c_SKUQty01         NVARCHAR(10)
         , @c_SKUQty02         NVARCHAR(10)
         , @c_SKUQty03         NVARCHAR(10)
         , @c_SKUQty04         NVARCHAR(10)
         , @c_SKUQty05         NVARCHAR(10)
         , @c_SKUQty06         NVARCHAR(10)
         , @c_SKUQty07         NVARCHAR(10)
         , @c_SKUQty08         NVARCHAR(10)
         , @c_STYLE01          NVARCHAR(50)
         , @c_STYLE02          NVARCHAR(50)
         , @c_STYLE03          NVARCHAR(50)
         , @c_STYLE04          NVARCHAR(50)
         , @c_STYLE05          NVARCHAR(50)
         , @c_STYLE06          NVARCHAR(50)
         , @c_STYLE07          NVARCHAR(50)
         , @c_STYLE08          NVARCHAR(50)
         , @c_ExtOrdkey        NVARCHAR(80)
         , @c_ExtOrdkey01      NVARCHAR(80)
         , @c_ExtOrdkey02      NVARCHAR(80)
         , @c_ExtOrdkey03      NVARCHAR(80)
         , @c_ExtOrdkey04      NVARCHAR(80)
         , @c_ExtOrdkey05      NVARCHAR(80)
         , @c_ExtOrdkey06      NVARCHAR(80)
         , @c_ExtOrdkey07      NVARCHAR(80)
         , @c_ExtOrdkey08      NVARCHAR(80)
         , @c_ExtOrdkey09      NVARCHAR(80)
         , @c_ExtOrdkey10      NVARCHAR(80)
         , @n_TTLpage          INT
         , @n_CurrentPage      INT
         , @n_MaxLine          INT
         , @c_labelno          NVARCHAR(20)
         , @c_orderkey         NVARCHAR(20)
         , @n_skuqty           INT
         , @n_skurqty          INT
         , @c_cartonno         NVARCHAR(5)
         , @n_loopno           INT
         , @c_LastRec          NVARCHAR(1)
         , @c_ExecStatements   NVARCHAR(4000)
         , @c_ExecArguments    NVARCHAR(4000)
         , @c_MaxLBLLine       INT
         , @c_SumQTY           INT
         , @c_CTNQTY           INT
         , @n_MaxCarton        INT
         , @c_Made             NVARCHAR(80)
         , @n_SumPack          INT
         , @n_SumPick          INT
         , @n_MaxCtnNo         INT
         , @c_STYLE            NVARCHAR(50)
         , @c_SSIZE            NVARCHAR(10)
         , @c_TableLinkage     NVARCHAR(500) --WL01

   SET @n_MaxCarton = 0

   SELECT @n_MaxCarton = MAX(PD.CartonNo)
   FROM PackDetail PD (NOLOCK)
   WHERE PD.PickSlipNo = @c_Sparm02

   SET @d_Trace_StartTime = GETDATE()
   SET @c_Trace_ModuleName = N''

   -- SET RowNo = 0               
   SET @c_SQL = N''
   SET @n_CurrentPage = 1
   SET @n_TTLpage = 1
   SET @n_MaxLine = 8
   SET @n_CntRec = 1
   SET @n_intFlag = 1
   SET @n_ExtOrdRow = 1
   SET @n_loopno = 1
   SET @c_LastRec = N'Y'

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

   CREATE TABLE [#TEMPSKU]
   (
      [ID]         [INT]          IDENTITY(1, 1) NOT NULL
    , [cartonno]   [NVARCHAR](5)  NULL
    , [labelno]    [NVARCHAR](20) NULL
    , [Size]       [NVARCHAR](10) NULL
    , [Pickslipno] [NVARCHAR](80) NULL
    , [STYLE]      [NVARCHAR](50) NULL
    , [PQty]       INT
   )

   CREATE TABLE [#TEMPExtOrd]
   (
      [ID]          [INT]          IDENTITY(1, 1) NOT NULL
    , [Loadkey]     [NVARCHAR](20) NULL
    , [ExtOrderkey] [NVARCHAR](20) NULL
    , [PickSlipnno] [NVARCHAR](20) NULL
   )

   --WL01 S
   SELECT @c_orderkey = PH.OrderKey
   FROM PackHeader PH (NOLOCK)
   WHERE PH.PickSlipNo = @c_Sparm02

   IF ISNULL(@c_orderkey, '') = '' --Conso
   BEGIN
      SET @c_TableLinkage = N' JOIN LOADPLANDETAIL LPD WITH (NOLOCK)  ON (LPD.Loadkey = PH.Loadkey) ' + CHAR(13)
                            + N' JOIN ORDERS ORD WITH (NOLOCK)  ON (ORD.Orderkey = LPD.Orderkey) '
   END
   ELSE
   BEGIN
      SET @c_TableLinkage = N' JOIN ORDERS ORD WITH (NOLOCK)  ON (ORD.Orderkey = PH.Orderkey) '
   END
   --WL01 E

   SET @c_SQLJOIN = +N' SELECT ST.company, PH.loadkey,'''','''','''',' + CHAR(13) --5
                    + N' '''','''','''','''','''', ' + CHAR(13) --10        
                    + N' '''', '''', PD.CartonNo, MAX(ORD.Consigneekey), STCON.City,STCON.company, ' --16   --WL01
                    + N' (ISNULL(STCON.Address1,'''') + ISNULL(STCON.Address2,'''') +  ISNULL(STCON.Address3,'''')), '
                    + CHAR(13) --17
                    + N' '''', '''', '''', ' + CHAR(13) --20
                    + N' '''','''','''','''','''','''','''','''','''','''', ' + CHAR(13) --30 
                    + N' '''','''','''','''','''','''','''','''','''','''', ' + CHAR(13) --40 
                    + N' '''','''',CASE WHEN MAX(ORD.type)=''IC'' THEN PD.Labelno ELSE ''LFSH'' + PD.Labelno END ,'''', '
                    + CHAR(13) --44   --WL01
                    + N' ISNULL(PD.DropID,''''),CASE WHEN MAX(ORD.type)=''IC'' THEN MAX(ORD.BuyerPO) ELSE '''' END,'''', ' --WL01  --CS01
                    + CHAR(13) --47 
                    + N''''','''','''', ' + CHAR(13) --50 
                    + N' '''','''','''','''','''','''','''', ' + CHAR(13) --58
                    + N' '''', '''',PD.Labelno ' + CHAR(13) --60               
                    + N' FROM PACKDETAIL PD  WITH (NOLOCK)      ' + CHAR(13)
                    + N' JOIN PACKHEADER PH WITH (NOLOCK)  ON (PD.PickSlipNo = PH.PickSlipNo) ' + CHAR(13)
                    + @c_TableLinkage + CHAR(13) --WL01
                    --+ N' JOIN ORDERS ORD WITH (NOLOCK)  ON (ORD.Orderkey = PH.Orderkey)    ' + CHAR(13)   --WL01
                    + N' LEFT JOIN STORER STCON WITH (NOLOCK) ON STCON.storerkey = ORD.consigneekey ' + CHAR(13)
                    + N' JOIN STORER ST WITH (NOLOCK) ON ST.Storerkey = ORD.Storerkey ' + CHAR(13)
                    + N' JOIN SKU WITH (NOLOCK) ON SKU.SKU = PD.SKU AND SKU.STORERKEY = PH.STORERKEY '
                    + CHAR(13)
                    --  +' JOIN PACKINFO PIF (NOLOCK) ON PIF.PICKSLIPNO = PH.PICKSLIPNO AND PIF.CARTONNO = PD.CARTONNO ' + CHAR(13)                   
                    + N' WHERE PH.PICKSLIPNO = @c_Sparm02       ' + CHAR(13) + N' AND PD.CartonNo = @c_Sparm04'
                    + CHAR(13) + N' AND PH.Storerkey = @c_Sparm01' + CHAR(13) + N' AND PD.Labelno = @c_Sparm05'
                    + CHAR(13)
                    + N' GROUP BY ST.company, PH.loadkey, ORD.Consigneekey,PD.CartonNo,STCON.City,STCON.company, '
                    + CHAR(13)
                    + N' (ISNULL(STCON.Address1,'''') + ISNULL(STCON.Address2,'''') +  ISNULL(STCON.Address3,'''')),'
                    + CHAR(13)
                    + N' CASE WHEN ORD.type=''IC'' THEN PD.Labelno ELSE ''LFSH'' + PD.Labelno END ,PD.Labelno, ISNULL(PD.DropID,'''') ' --WL01

   IF @b_debug = 1
   BEGIN
      PRINT @c_SQLJOIN
   END

   SET @c_SQL = N'INSERT INTO #Result (Col01,Col02,Col03,Col04,Col05, Col06,Col07,Col08,Col09' + CHAR(13)
                + +N',Col10,Col11,Col12,Col13,Col14,Col15,Col16,Col17,Col18,Col19,Col20,Col21,Col22' + CHAR(13)
                + +N',Col23,Col24,Col25,Col26,Col27,Col28,Col29,Col30,Col31,Col32,Col33,Col34' + CHAR(13)
                + +N',Col35,Col36,Col37,Col38,Col39,Col40,Col41,Col42,Col43,Col44' + CHAR(13)
                + +N',Col45,Col46,Col47,Col48,Col49,Col50,Col51,Col52,Col53,Col54' + CHAR(13)
                + +N',Col55,Col56,Col57,Col58,Col59,Col60) '

     SET @c_SQL = @c_SQL + @c_SQLJOIN


     SET @c_ExecArguments = N'     @c_Sparm01          NVARCHAR(80)' + N',    @c_Sparm02          NVARCHAR(80)'
                          + N',    @c_Sparm04          NVARCHAR(80)' + N',    @c_Sparm05          NVARCHAR(80)'


   EXEC sp_executesql @c_SQL
                    , @c_ExecArguments
                    , @c_Sparm01
                    , @c_Sparm02
                    , @c_Sparm04
                    , @c_Sparm05


   --EXEC sp_executesql @c_SQL            

   IF @b_debug = 1
   BEGIN
      PRINT @c_SQL
   END


   IF @b_debug = 1
   BEGIN
      SELECT *
      FROM #Result (NOLOCK)
   END

   DECLARE CUR_ExtOrdLoop CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT DISTINCT Col02
   FROM #Result
   ORDER BY Col02

   OPEN CUR_ExtOrdLoop

   FETCH NEXT FROM CUR_ExtOrdLoop
   INTO @c_LoadKey

   WHILE @@FETCH_STATUS <> -1
   BEGIN
      IF @b_debug = '1'
      BEGIN
         PRINT @c_labelno
      END

      INSERT INTO #TEMPExtOrd (Loadkey, ExtOrderkey, PickSlipnno)
      SELECT TOP 10 ORD.LoadKey
                  , ORD.ExternOrderKey
                  , @c_Sparm02
      FROM LoadPlanDetail (NOLOCK)
      JOIN ORDERS ORD WITH (NOLOCK) ON ORD.OrderKey = LoadPlanDetail.OrderKey
      WHERE LoadPlanDetail.LoadKey = @c_LoadKey
      GROUP BY ORD.LoadKey
             , ORD.ExternOrderKey
      ORDER BY ORD.ExternOrderKey

      -- select * from  #TEMPExtOrd

      SET @c_ExtOrdkey01 = N''
      SET @c_ExtOrdkey02 = N''
      SET @c_ExtOrdkey03 = N''
      SET @c_ExtOrdkey04 = N''
      SET @c_ExtOrdkey05 = N''
      SET @c_ExtOrdkey06 = N''
      SET @c_ExtOrdkey07 = N''
      SET @c_ExtOrdkey08 = N''
      SET @c_ExtOrdkey09 = N''
      SET @c_ExtOrdkey10 = N''

      WHILE @n_ExtOrdRow <= 10    --WL01 
      BEGIN                       --WL01 
         SET @c_ExtOrdkey = N''   --WL01 

         SELECT @c_ExtOrdkey = ExtOrderkey
         FROM #TEMPExtOrd
         WHERE ID = @n_ExtOrdRow

         IF @n_ExtOrdRow = 1
         BEGIN
            SET @c_ExtOrdkey01 = @c_ExtOrdkey
         END
         ELSE IF @n_ExtOrdRow = 2
         BEGIN
            SET @c_ExtOrdkey02 = @c_ExtOrdkey
         END
         ELSE IF @n_ExtOrdRow = 3
         BEGIN
            SET @c_ExtOrdkey03 = @c_ExtOrdkey
         END
         ELSE IF @n_ExtOrdRow = 4
         BEGIN
            SET @c_ExtOrdkey04 = @c_ExtOrdkey
         END
         ELSE IF @n_ExtOrdRow = 5
         BEGIN
            SET @c_ExtOrdkey05 = @c_ExtOrdkey
         END
         ELSE IF @n_ExtOrdRow = 6
         BEGIN
            SET @c_ExtOrdkey06 = @c_ExtOrdkey
         END
         ELSE IF @n_ExtOrdRow = 7
         BEGIN
            SET @c_ExtOrdkey07 = @c_ExtOrdkey
         END
         ELSE IF @n_ExtOrdRow = 8
         BEGIN
            SET @c_ExtOrdkey08 = @c_ExtOrdkey
         END
         ELSE IF @n_ExtOrdRow = 9
         BEGIN
            SET @c_ExtOrdkey09 = @c_ExtOrdkey
         END
         ELSE IF @n_ExtOrdRow = 10
         BEGIN
            SET @c_ExtOrdkey10 = @c_ExtOrdkey
         END

         UPDATE #Result
         SET Col03 = @c_ExtOrdkey01
           , Col04 = @c_ExtOrdkey02
           , Col05 = @c_ExtOrdkey03
           , Col06 = @c_ExtOrdkey04
           , Col07 = @c_ExtOrdkey05
           , Col08 = @c_ExtOrdkey06
           , Col09 = @c_ExtOrdkey07
           , Col10 = @c_ExtOrdkey08
           , Col11 = @c_ExtOrdkey09
           , Col12 = @c_ExtOrdkey10

         SET @n_ExtOrdRow = @n_ExtOrdRow + 1

         IF @n_ExtOrdRow > 10
         BEGIN
            BREAK;
         END
      END   --WL01 
      
      FETCH NEXT FROM CUR_ExtOrdLoop
      INTO @c_LoadKey

   END -- While                     
   CLOSE CUR_ExtOrdLoop
   DEALLOCATE CUR_ExtOrdLoop


   DECLARE CUR_RowNoLoop CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT DISTINCT Col60
                 , Col13
   FROM #Result
   ORDER BY Col13

   OPEN CUR_RowNoLoop

   FETCH NEXT FROM CUR_RowNoLoop
   INTO @c_labelno
      , @c_cartonno

   WHILE @@FETCH_STATUS <> -1
   BEGIN
      IF @b_debug = '1'
      BEGIN
         PRINT @c_labelno
      END

      INSERT INTO #TEMPSKU (cartonno, labelno, Pickslipno, Size, STYLE, PQty)
      SELECT DISTINCT PD.CartonNo
                    , PD.LabelNo
                    , @c_Sparm02
                    , LTRIM(RTRIM(ISNULL(SKU.Size, '')))
                    , LTRIM(RTRIM(ISNULL(SKU.Style, '')))
                    , PD.Qty
      FROM PackDetail PD (NOLOCK)
      JOIN PackHeader PH (NOLOCK) ON PH.PickSlipNo = PD.PickSlipNo
      JOIN SKU (NOLOCK) ON PD.SKU = SKU.Sku AND PH.StorerKey = SKU.StorerKey
      WHERE PH.PickSlipNo = @c_Sparm02 AND PD.LabelNo = @c_labelno AND PD.CartonNo = @c_cartonno
      GROUP BY PD.LabelNo
             , PD.CartonNo
             , PD.Qty
             , SKU.Style
             , SKU.Size
      ORDER BY PD.CartonNo
             , LTRIM(RTRIM(ISNULL(SKU.Style, '')))    --WL02
             , LTRIM(RTRIM(ISNULL(SKU.Size, '')))     --WL02

      SET @c_SSIZE01 = N''
      SET @c_SSIZE02 = N''
      SET @c_SSIZE03 = N''
      SET @c_SSIZE04 = N''
      SET @c_SSIZE05 = N''
      SET @c_SSIZE06 = N''
      SET @c_SSIZE07 = N''
      SET @c_SSIZE08 = N''

      SET @c_SKUQty01 = N''
      SET @c_SKUQty02 = N''
      SET @c_SKUQty03 = N''
      SET @c_SKUQty04 = N''
      SET @c_SKUQty05 = N''
      SET @c_SKUQty06 = N''
      SET @c_SKUQty07 = N''
      SET @c_SKUQty08 = N''

      SET @c_STYLE01 = N''
      SET @c_STYLE02 = N''
      SET @c_STYLE03 = N''
      SET @c_STYLE04 = N''
      SET @c_STYLE05 = N''
      SET @c_STYLE06 = N''
      SET @c_STYLE07 = N''
      SET @c_STYLE08 = N''

      --SELECT * FROM #TEMPSKU  

      SELECT @n_CntRec = COUNT(1)
      FROM #TEMPSKU
      WHERE labelno = @c_labelno AND cartonno = @c_cartonno

      SET @n_TTLpage = FLOOR(@n_CntRec / @n_MaxLine) + CASE WHEN @n_CntRec % @n_MaxLine > 0 THEN 1
                                                            ELSE 0 END

      WHILE @n_intFlag <= @n_CntRec
      BEGIN

         IF @n_intFlag > @n_MaxLine AND (@n_intFlag % @n_MaxLine) = 1 --AND @c_LastRec = 'N'  
         BEGIN

            SET @n_CurrentPage = @n_CurrentPage + 1

            IF (@n_CurrentPage > @n_TTLpage)
            BEGIN
               BREAK;
            END

            INSERT INTO #Result (Col01, Col02, Col03, Col04, Col05, Col06, Col07, Col08, Col09, Col10, Col11, Col12
                               , Col13, Col14, Col15, Col16, Col17, Col18, Col19, Col20, Col21, Col22, Col23, Col24
                               , Col25, Col26, Col27, Col28, Col29, Col30, Col31, Col32, Col33, Col34, Col35, Col36
                               , Col37, Col38, Col39, Col40, Col41, Col42, Col43, Col44, Col45, Col46, Col47, Col48
                               , Col49, Col50, Col51, Col52, Col53, Col54, Col55, Col56, Col57, Col58, Col59, Col60)
            SELECT TOP 1 Col01
                       , Col02
                       , Col03
                       , Col04
                       , Col05
                       , Col06
                       , Col07
                       , Col08
                       , Col09
                       , Col10
                       , Col11
                       , Col12
                       , Col13
                       , Col14
                       , Col15
                       , Col16
                       , Col17
                       , ''
                       , ''
                       , ''
                       , ''
                       , ''
                       , ''
                       , ''
                       , ''
                       , ''
                       , ''
                       , ''
                       , ''
                       , ''
                       , ''
                       , ''
                       , ''
                       , ''
                       , ''
                       , ''
                       , ''
                       , ''
                       , ''
                       , ''
                       , ''
                       , ''
                       , Col43
                       , ''
                       , Col45 --WL01
                       , ''
                       , ''
                       , ''
                       , ''
                       , ''
                       , ''
                       , ''
                       , ''
                       , ''
                       , ''
                       , ''
                       , ''
                       , ''
                       , ''
                       , Col60
            FROM #Result

            SET @c_SSIZE01 = N''
            SET @c_SSIZE02 = N''
            SET @c_SSIZE03 = N''
            SET @c_SSIZE04 = N''
            SET @c_SSIZE05 = N''
            SET @c_SSIZE06 = N''
            SET @c_SSIZE07 = N''
            SET @c_SSIZE08 = N''


            SET @c_SKUQty01 = N''
            SET @c_SKUQty02 = N''
            SET @c_SKUQty03 = N''
            SET @c_SKUQty04 = N''
            SET @c_SKUQty05 = N''
            SET @c_SKUQty06 = N''
            SET @c_SKUQty07 = N''
            SET @c_SKUQty08 = N''


            SET @c_STYLE01 = N''
            SET @c_STYLE02 = N''
            SET @c_STYLE03 = N''
            SET @c_STYLE04 = N''
            SET @c_STYLE05 = N''
            SET @c_STYLE06 = N''
            SET @c_STYLE07 = N''
            SET @c_STYLE08 = N''

         END

         SELECT @n_skuqty = SUM(PQty)
              , @c_SSIZE = Size
              , @c_STYLE = STYLE
         FROM #TEMPSKU
         WHERE ID = @n_intFlag
         GROUP BY Size
                , STYLE

         IF (@n_intFlag % @n_MaxLine) = 1 --AND @n_recgrp = @n_CurrentPage  
         BEGIN
            SET @c_SKUQty01 = CONVERT(NVARCHAR(10), @n_skuqty)
            SET @c_SSIZE01 = @c_SSIZE
            SET @c_STYLE01 = @c_STYLE
         END
         ELSE IF (@n_intFlag % @n_MaxLine) = 2 --AND @n_recgrp = @n_CurrentPage  
         BEGIN
            SET @c_SKUQty02 = CONVERT(NVARCHAR(10), @n_skuqty)
            SET @c_SSIZE02 = @c_SSIZE
            SET @c_STYLE02 = @c_STYLE
         END
         ELSE IF (@n_intFlag % @n_MaxLine) = 3 --AND @n_recgrp = @n_CurrentPage  
         BEGIN
            SET @c_SKUQty03 = CONVERT(NVARCHAR(10), @n_skuqty)
            SET @c_SSIZE03 = @c_SSIZE
            SET @c_STYLE03 = @c_STYLE
         END
         ELSE IF (@n_intFlag % @n_MaxLine) = 4 --AND @n_recgrp = @n_CurrentPage  
         BEGIN
            SET @c_SKUQty04 = CONVERT(NVARCHAR(10), @n_skuqty)
            SET @c_SSIZE04 = @c_SSIZE
            SET @c_STYLE04 = @c_STYLE
         END
         ELSE IF (@n_intFlag % @n_MaxLine) = 5 --AND @n_recgrp = @n_CurrentPage  
         BEGIN
            SET @c_SKUQty05 = CONVERT(NVARCHAR(10), @n_skuqty)
            SET @c_SSIZE05 = @c_SSIZE
            SET @c_STYLE05 = @c_STYLE
         END
         ELSE IF (@n_intFlag % @n_MaxLine) = 6 --AND @n_recgrp = @n_CurrentPage  
         BEGIN
            SET @c_SKUQty06 = CONVERT(NVARCHAR(10), @n_skuqty)
            SET @c_SSIZE06 = @c_SSIZE
            SET @c_STYLE06 = @c_STYLE
         END
         ELSE IF (@n_intFlag % @n_MaxLine) = 7 --AND @n_recgrp = @n_CurrentPage  
         BEGIN
            SET @c_SKUQty07 = CONVERT(NVARCHAR(10), @n_skuqty)
            SET @c_SSIZE07 = @c_SSIZE
            SET @c_STYLE07 = @c_STYLE
         END
         ELSE IF (@n_intFlag % @n_MaxLine) = 0 --AND @n_recgrp = @n_CurrentPage  
         BEGIN
            SET @c_SKUQty08 = CONVERT(NVARCHAR(10), @n_skuqty)
            SET @c_SSIZE08 = @c_SSIZE
            SET @c_STYLE08 = @c_STYLE
         END

         UPDATE #Result
         SET Col18 = @c_STYLE01
           , Col19 = @c_SSIZE01
           , Col20 = @c_SKUQty01
           , Col21 = @c_STYLE02
           , Col22 = @c_SSIZE02
           , Col23 = @c_SKUQty02
           , Col24 = @c_STYLE03
           , Col25 = @c_SSIZE03
           , Col26 = @c_SKUQty03
           , Col27 = @c_STYLE04
           , Col28 = @c_SSIZE04
           , Col29 = @c_SKUQty04
           , Col30 = @c_STYLE05
           , Col31 = @c_SSIZE05
           , Col32 = @c_SKUQty05
           , Col33 = @c_STYLE06
           , Col34 = @c_SSIZE06
           , Col35 = @c_SKUQty06
           , Col36 = @c_STYLE07
           , Col37 = @c_SSIZE07
           , Col38 = @c_SKUQty07
           , Col39 = @c_STYLE08
           , Col40 = @c_SSIZE08
           , Col41 = @c_SKUQty08
         WHERE ID = @n_CurrentPage

         SET @n_intFlag = @n_intFlag + 1

         IF @n_intFlag > @n_CntRec
         BEGIN
            BREAK;
         END
      END
      FETCH NEXT FROM CUR_RowNoLoop
      INTO @c_labelno
         , @c_cartonno

   END -- While                     
   CLOSE CUR_RowNoLoop
   DEALLOCATE CUR_RowNoLoop

   UPDATE #Result
   SET Col42 = (  SELECT SUM(Qty)
                  FROM PackDetail (NOLOCK)
                  WHERE PickSlipNo = @c_Sparm02 AND CartonNo = @c_Sparm04)
     , Col44 = @n_MaxCarton
   WHERE Col13 = @c_Sparm04 AND Col60 = @c_Sparm05

   SELECT *
   FROM #Result

   EXIT_SP:

   SET @d_Trace_EndTime = GETDATE()
   SET @c_UserName = SUSER_SNAME()

   EXEC isp_InsertTraceInfo @c_TraceCode = 'BARTENDER'
                          , @c_TraceName = 'isp_BT_Bartender_SHIPLBLLVS_01'
                          , @c_StartTime = @d_Trace_StartTime
                          , @c_EndTime   = @d_Trace_EndTime
                          , @c_Step1     = @c_UserName
                          , @c_Step2     = ''
                          , @c_Step3     = ''
                          , @c_Step4     = ''
                          , @c_Step5     = ''
                          , @c_Col1      = @c_Sparm01
                          , @c_Col2      = @c_Sparm02
                          , @c_Col3      = @c_Sparm03
                          , @c_Col4      = @c_Sparm04
                          , @c_Col5      = @c_Sparm05
                          , @b_Success   = 1
                          , @n_Err       = 0
                          , @c_ErrMsg    = ''

END -- procedure  

GO