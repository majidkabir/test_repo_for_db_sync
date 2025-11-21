SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Copyright: IDS                                                             */
/* Purpose: isp_BT_Bartender_TW_Ship_Label_01                                 */
/*                                                                            */
/* Modifications log:                                                         */
/*                                                                            */
/* Date       Rev  Author     Purposes                                        */
/* 2017-01-16 1.0  CSCHONG    Created (WMS-932)                               */
/* 2017-04-03 1.1  CSCHONG    WMS-1519 Add new field,change field mapping(CS01)*/
/* 2017-05-04 1.2  CSCHONG    WMS-1814 Add new field Col13 (CS02)             */
/* 2017-10-19 1.3  SPChin     INC0013893 - Bug Fixed                          */
/* 2018-10-15 1.4  LZG        INC0414464 - Display Orders.C_Company if        */
/*                            Orders.ConsigneeKey is empty (ZG01)             */
/* 2021-03-03 1.5  WLChooi    WMS-16450 Add logic to get Col02 & Col13 (WL01) */
/******************************************************************************/

CREATE PROC [dbo].[isp_BT_Bartender_TW_Ship_Label_01]
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

   DECLARE
      @c_ExternOrderkey  NVARCHAR(10),
      @c_Sku             NVARCHAR(20),
      @n_intFlag         INT,
      @n_CntRec          INT,
      @c_SQL             NVARCHAR(4000),
      @c_SQLSORT         NVARCHAR(4000),
      @c_SQLJOIN         NVARCHAR(4000),
      @n_totalcase       INT,
      @n_sequence        INT,
      @c_skugroup        NVARCHAR(10),
      @n_CntSku          INT,
      @n_TTLQty          INT,
      @c_ExecStatements  NVARCHAR(4000),       --(CS01)
      @c_ExecArguments   NVARCHAR(4000),        --(CS01)
      @c_storerkey       NVARCHAR(20),          --(CS01)
      @c_col06           NVARCHAR(80) = '',     --(CS01)   --WL01
      @c_getcol06        NVARCHAR(80),          --(CS01)
      @c_Col02           NVARCHAR(100) = '',    --WL01
      @c_Col13           NVARCHAR(100) = '',    --WL01
      @c_Col09           NVARCHAR(100) = '',    --WL01
      @c_Col09Table      NVARCHAR(100) = '',    --WL01
      @c_Col09Column     NVARCHAR(100) = '',    --WL01
      @c_Col09DataType   NVARCHAR(100) = '',    --WL01
      @c_GetStorerkey    NVARCHAR(15)  = ''     --WL01


   DECLARE @d_Trace_StartTime   DATETIME,
           @d_Trace_EndTime    DATETIME,
           @c_Trace_ModuleName NVARCHAR(20),
           @d_Trace_Step1      DATETIME,
           @c_Trace_Step1      NVARCHAR(20),
           @c_UserName         NVARCHAR(20)

   SET @d_Trace_StartTime = GETDATE()
   SET @c_Trace_ModuleName = ''

   -- SET RowNo = 0
   SET @c_SQL = ''
   SET @c_Sku = ''
   SET @c_skugroup = ''
   SET @n_totalcase = 0
   SET @n_sequence  = 1
   SET @n_CntSku = 1
   SET @n_TTLQty = 0
   
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

   /*CS01 start*/
   SET @c_getcol06 = ''
   SET @c_storerkey = ''

   SELECT TOP 1 @c_getcol06 = C.notes,
                @c_storerkey = s.StorerKey
   FROM PackHeader AS ph WITH (NOLOCK)
   JOIN PackDetail AS pd WITH (NOLOCK) ON pd.PickSlipNo = ph.PickSlipNo
   JOIN ORDERS AS o WITH (NOLOCK) ON o.OrderKey = ph.OrderKey
   JOIN Storer S WITH (NOLOCK) ON S.StorerKey = o.ConsigneeKey
   LEFT JOIN Codelkup C WITH (NOLOCK) on C.listname='REPORTCFG' AND C.Code='B2Blabel01'
                                     and C.long ='isp_BT_Bartender_TW_Ship_Label_01' and C.storerkey = O.storerkey
   WHERE pd.pickslipno = @c_Sparm01
   AND pd.labelno =  @c_Sparm02

   IF @b_debug = '1'
   BEGIN
      PRINT ' Get GetCol06 : ' + @c_GetCol06 + ' with storerkey : ' +   @c_storerkey
   END

   SET @c_ExecStatements = ''
   SET @c_ExecArguments = ''

   --INC0013893 Start
   IF ISNULL(@c_getcol06,'') <> ''
   BEGIN
      SET @c_ExecStatements = N'SELECT @c_col06 =' + @c_GetCol06 + ' FROM STORER WITH (NOLOCK) '
                            +  'where storerkey=@c_storerkey '

      SET @c_ExecArguments = N' @c_Getcol06    NVARCHAR(80) '
                           +  ',@c_storerkey   NVARCHAR(30) '
                           +  ',@c_col06       NVARCHAR(80) OUTPUT'

      EXEC sp_ExecuteSql @c_ExecStatements
                       , @c_ExecArguments
                       , @c_Getcol06
                       , @c_storerkey
                       , @c_col06 OUTPUT
   END
   --INC0013893 End

   IF @b_debug = '1'
   BEGIN
      PRINT ' col06 : ' + @c_col06
   END

   /*CS01 End*/
   
   IF @c_getcol06 = '' AND @c_col06 = ''                  -- ZG01
   BEGIN
      SELECT @c_col06 = O.C_Company FROM Orders O (NOLOCK)
      JOIN PackHeader PH WITH (NOLOCK) ON O.OrderKey = PH.OrderKey
      JOIN PackDetail PD WITH (NOLOCK) ON PH.PickSlipNo = PD.PickSlipNo
      WHERE PH.PickSlipNo = @c_Sparm01
      AND PD.LabelNo = @c_Sparm02
   END
   
   --WL01 S
   SELECT @c_GetStorerkey = Storerkey
   FROM PACKHEADER (NOLOCK)
   WHERE PickSlipNo = @c_Sparm01
   
   SELECT @c_Col02 = ISNULL(CODELKUP.Notes, 'ISNULL(SSOD.Route,'''')')
   FROM CODELKUP (NOLOCK) 
   WHERE LISTNAME = 'REPORTCFG' 
   AND Code = 'GetCol02' 
   AND Long = 'isp_BT_Bartender_TW_Ship_Label_01' 
   AND Short = 'Y' 
   AND Storerkey = @c_GetStorerkey

   IF ISNULL(@c_Col02,'') = ''
   BEGIN 
      SET @c_Col02 = N'ISNULL(SSOD.Route,'''')'
   END
   
   SELECT @c_Col13 = ISNULL(CODELKUP.Notes, 'o.orderkey')
   FROM CODELKUP (NOLOCK) 
   WHERE LISTNAME = 'REPORTCFG' 
   AND Code = 'GetCol13' 
   AND Long = 'isp_BT_Bartender_TW_Ship_Label_01' 
   AND Short = 'Y' 
   AND Storerkey = @c_GetStorerkey

   IF ISNULL(@c_Col13,'') = ''
   BEGIN 
      SET @c_Col13 = N'o.orderkey'
   END
   
   SELECT @c_Col09 = ISNULL(CODELKUP.Notes, 'o.DeliveryDate')
   FROM CODELKUP (NOLOCK) 
   WHERE LISTNAME = 'REPORTCFG' 
   AND Code = 'GetCol09' 
   AND Long = 'isp_BT_Bartender_TW_Ship_Label_01' 
   AND Short = 'Y' 
   AND Storerkey = @c_GetStorerkey

   IF ISNULL(@c_Col09,'') = ''
   BEGIN 
      SET @c_Col09 = N'o.DeliveryDate'
   END
   
   SELECT @c_Col09Table  = SUBSTRING(@c_Col09, 1, CHARINDEX('.', @c_Col09) - 1)
   SELECT @c_Col09Column = SUBSTRING(@c_Col09, CHARINDEX('.',@c_Col09) + 1, 80)
   
   SELECT @c_Col09Table = CASE WHEN @c_Col09Table = 'o'    THEN 'ORDERS'
                               WHEN @c_Col09Table = 'ph'   THEN 'PackHeader'
                               WHEN @c_Col09Table = 'pd'   THEN 'PackDetail'
                               WHEN @c_Col09Table = 'ssod' THEN 'StorerSODefault'
                               WHEN @c_Col09Table = 'c'    THEN 'CODELKUP'
                               WHEN @c_Col09Table = 'LP'   THEN 'LOADPLAN'
                               WHEN @c_Col09Table = 'LPD'  THEN 'LOADPLANDETAIL'
                               ELSE 'ORDERS' END
                                
   SELECT @c_Col09DataType = Col.DATA_TYPE
   FROM INFORMATION_SCHEMA.COLUMNS Col WITH (NOLOCK)  
   WHERE Col.Table_Name = @c_Col09Table
   AND Col.COLUMN_NAME = @c_Col09Column

   IF @c_Col09DataType = 'DateTime'
   BEGIN
      SET @c_Col09 = 'CONVERT(NVARCHAR(10),' + @c_Col09 + ',111)'    
   END
   
   --Use IF Exists to prevent overwrite above value for Col06
   IF EXISTS ( SELECT 1
               FROM CODELKUP (NOLOCK) 
               WHERE LISTNAME = 'REPORTCFG' 
               AND Code = 'GetCol06' 
               AND Long = 'isp_BT_Bartender_TW_Ship_Label_01' 
               AND Short = 'Y' 
               AND Storerkey = @c_GetStorerkey)
   BEGIN
      SELECT @c_Col06 = ISNULL(CODELKUP.Notes, 'o.C_Company')
      FROM CODELKUP (NOLOCK) 
      WHERE LISTNAME = 'REPORTCFG' 
      AND Code = 'GetCol06' 
      AND Long = 'isp_BT_Bartender_TW_Ship_Label_01' 
      AND Short = 'Y' 
      AND Storerkey = @c_GetStorerkey
      
      IF ISNULL(@c_Col06,'') = ''
      BEGIN 
         SET @c_Col06 = N'o.C_Company'
      END
      
      SET @c_ExecStatements =   ' SELECT @c_col06 = ' + @c_Col06
                              + ' FROM PackHeader AS ph WITH (NOLOCK)'
                              + ' JOIN PackDetail AS pd WITH (NOLOCK) ON pd.PickSlipNo = ph.PickSlipNo'
                              + ' JOIN ORDERS AS o WITH (NOLOCK) ON o.OrderKey = ph.OrderKey '
                              + ' JOIN LOADPLANDETAIL LPD WITH (NOLOCK) ON LPD.Orderkey = o.Orderkey '
                              + ' JOIN LOADPLAN LP WITH (NOLOCK) ON LP.Loadkey = LPD.Loadkey '
                              + ' LEFT JOIN StorerSODefault SSOD WITH (NOLOCK) ON SSOD.storerkey=o.consigneekey '
                              + ' LEFT JOIN CODELKUP C WITH (NOLOCK) ON c.listname=''LabelType'' AND C.Code=O.Userdefine01 and C.storerkey = O.storerkey'
                              + ' WHERE PH.PickSlipNo = @c_Sparm01'
                              + ' AND PD.LabelNo = @c_Sparm02'
      
      EXEC sp_executesql @c_SQL
      
      SET @c_ExecArguments = N' @c_Sparm01     NVARCHAR(80) '
                           +  ',@c_Sparm02     NVARCHAR(80) '
                           +  ',@c_col06       NVARCHAR(80) OUTPUT'

      EXEC sp_ExecuteSql @c_ExecStatements
                       , @c_ExecArguments
                       , @c_Sparm01
                       , @c_Sparm02
                       , @c_col06 OUTPUT
      
      SET @c_ExecStatements = ''
      SET @c_ExecArguments  = ''
   END
   --WL01 E

   SET @c_SQLJOIN = +N' SELECT DISTINCT (pd.pickslipno + RIGHT(''000''+CAST(pd.cartonno AS VARCHAR(3)),3)), ' + @c_Col02 + ','   --WL01
                    + ' o.ExternOrderKey,pd.CartonNo,'       --4
                    + ' SUM(pd.Qty) AS PQty, N''' + @c_col06 + ''',ISNULL(o.Consigneekey,''''),ISNULL(o.C_Address1,''''),' --8                         --CS01
                    + ' ' + @c_Col09 + ' ,ISNULL(o.notes,''''),ISNULL(C.Long,''''),o.Storerkey,' + @c_Col13 + ',O.Door,'''', ' --15    --CS01  --CS02   --WL01
                    + ' '''','''','''','''','''','     --20
                    --    + CHAR(13) +
                    + ' '''','''','''','''','''','''','''','''','''','''','  --30
                    + ' '''','''','''','''','''','''','''','''','''','''','   --40
                    + ' '''','''','''','''','''','''','''','''','''','''', '  --50
                    + ' '''','''','''','''','''','''','''','''','''',''TW'' '   --60
                    --  + CHAR(13) +
                    + ' FROM PackHeader AS ph WITH (NOLOCK)'
                    + ' JOIN PackDetail AS pd WITH (NOLOCK) ON pd.PickSlipNo = ph.PickSlipNo'
                    + ' JOIN ORDERS AS o WITH (NOLOCK) ON o.OrderKey = ph.OrderKey '
                    + ' JOIN LOADPLANDETAIL LPD WITH (NOLOCK) ON LPD.Orderkey = o.Orderkey '   --WL01
                    + ' JOIN LOADPLAN LP WITH (NOLOCK) ON LP.Loadkey = LPD.Loadkey '   --WL01
                    + ' LEFT JOIN StorerSODefault SSOD WITH (NOLOCK) ON SSOD.storerkey=o.consigneekey '
                    --  + ' JOIN Storer WITH (NOLOCK) ON Storer.storerkey = ph.storerkey '                                     --(CS01)
                    + ' LEFT JOIN CODELKUP C WITH (NOLOCK) ON c.listname=''LabelType'' AND C.Code=O.Userdefine01 and C.storerkey = O.storerkey'
                    -- + ' LEFT JOIN CODELKUP C1 WITH (NOLOCK) ON C1.listname=''REPORTCFG'' AND C1.Code=''B2Blabel01'' '                                        --CS01
                    -- + '                                        and C1.long =''isp_BT_Bartender_TW_Ship_Label_01'' and C1.storerkey = O.storerkey'
                    + ' WHERE pd.pickslipno =''' + @c_Sparm01+ ''' '
                    + ' AND pd.labelno = '''+ @c_Sparm02+ ''' '
                    + ' GROUP BY pd.pickslipno, ' + @c_Col02 + ',o.ExternOrderKey,pd.CartonNo,ISNULL(o.Consigneekey,''''), '   --WL01
                    + ' ISNULL(o.C_Address1,''''),' + @c_Col09 + ',ISNULL(o.notes,''''),ISNULL(C.Long,''''),o.Storerkey,' + @c_Col13 + ',O.Door'  --CS01   --CS02   --WL01

   IF @b_debug=1
   BEGIN
      SELECT @c_SQLJOIN
   END

   SET @c_SQL='INSERT INTO #Result (Col01,Col02,Col03,Col04,Col05, Col06,Col07,Col08,Col09'  + CHAR(13) +
             +',Col10,Col11,Col12,Col13,Col14,Col15,Col16,Col17,Col18,Col19,Col20,Col21,Col22'  + CHAR(13) +
             +',Col23,Col24,Col25,Col26,Col27,Col28,Col29,Col30,Col31,Col32,Col33,Col34' + CHAR(13) +
             +',Col35,Col36,Col37,Col38,Col39,Col40,Col41,Col42,Col43,Col44'  + CHAR(13) +
             +',Col45,Col46,Col47,Col48,Col49,Col50,Col51,Col52,Col53,Col54'+ CHAR(13) +
             +',Col55,Col56,Col57,Col58,Col59,Col60) '

   SET @c_SQL = @c_SQL + @c_SQLJOIN

   EXEC sp_executesql @c_SQL

   IF @b_debug=1
   BEGIN
      PRINT @c_SQL
   END
   IF @b_debug=1
   BEGIN
      SELECT * FROM #Result (nolock)
   END
   
   EXIT_SP:

   SET @d_Trace_EndTime = GETDATE()
   SET @c_UserName = SUSER_SNAME()

   EXEC isp_InsertTraceInfo
      @c_TraceCode = 'BARTENDER',
      @c_TraceName = 'isp_BT_Bartender_TW_Ship_Label_01',
      @c_starttime = @d_Trace_StartTime,
      @c_endtime = @d_Trace_EndTime,
      @c_step1 = @c_UserName,
      @c_step2 = '',
      @c_step3 = '',
      @c_step4 = '',
      @c_step5 = '',
      @c_col1 = @c_Sparm01,
      @c_col2 = @c_Sparm02,
      @c_col3 = @c_Sparm03,
      @c_col4 = @c_Sparm04,
      @c_col5 = @c_Sparm05,
      @b_Success = 1,
      @n_Err = 0,
      @c_ErrMsg = ''

   SELECT * FROM #Result (nolock)

END -- procedure

GO