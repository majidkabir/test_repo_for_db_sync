SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/    
/* Copyright: LFL                                                             */    
/* Purpose: isp_BT_Bartender_AU_VASXDLBL01_FARMER                             */    
/*                                                                            */    
/* Modifications log:                                                         */    
/*                                                                            */    
/* Date        Rev  Author     Purposes                                       */    
/* 27-Mar-2023 1.0  WLChooi    Created (WMS-21983)                            */    
/* 27-Mar-2023 1.0  WLChooi    DevOps Combine Script                          */    
/* 27-Jul-2023 1.1  WLChooi    WMS-23221 - Logic Change (WL01)                */
/******************************************************************************/    
    
CREATE   PROC [dbo].[isp_BT_Bartender_AU_VASXDLBL01_FARMER]
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
         , @c_Orderkey       NVARCHAR(10)    
    
   DECLARE @d_Trace_StartTime  DATETIME    
         , @d_Trace_EndTime    DATETIME    
         , @c_Trace_ModuleName NVARCHAR(20)    
         , @d_Trace_Step1      DATETIME    
         , @c_Trace_Step1      NVARCHAR(20)    
         , @c_UserName         NVARCHAR(50)    
    
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

   --WL01 S
   DECLARE @c_C_Country NVARCHAR(100) = ''
         , @c_C_ISOCntryCode NVARCHAR(100) = ''
         , @c_M_Zip NVARCHAR(100) = ''
         , @c_M_State NVARCHAR(100) = ''

   SELECT @c_C_Country = OH.C_Country
        , @c_C_ISOCntryCode = OH.C_ISOCntryCode
        , @c_M_Zip = OH.M_Zip
   FROM PACKDETAIL PD (NOLOCK)
   JOIN PACKHEADER PH (NOLOCK) ON PH.PickSlipNo = PD.PickSlipNo
   JOIN ORDERS OH (NOLOCK) ON OH.OrderKey = PH.OrderKey
   WHERE PD.StorerKey = @c_Sparm1 AND PD.LabelNo = @c_Sparm2

   SELECT @c_M_State = CASE WHEN @c_C_Country = 'AU' OR @c_C_ISOCntryCode = 'AU' THEN CASE WHEN @c_M_Zip LIKE '3%' THEN 'VIC'
                                                                                           WHEN @c_M_Zip LIKE '4%' THEN 'QLD'
                                                                                           WHEN @c_M_Zip LIKE '5%' THEN 'SA'
                                                                                           WHEN @c_M_Zip LIKE '0%' THEN 'NT'
                                                                                           WHEN @c_M_Zip LIKE '6%' THEN 'WA'
                                                                                           WHEN @c_M_Zip LIKE '7%' THEN 'TAS'
                                                                                           WHEN ((@c_M_Zip >= '2600' AND @c_M_Zip <= '2618') 
                                                                                              OR (@c_M_Zip >= '2900' AND @c_M_Zip <= '2920')) THEN 'ACT'
                                                                                           ELSE 'NSW' 
                                                                                           END
                            WHEN @c_C_Country = 'NZ' OR @c_C_ISOCntryCode = 'NZ' THEN CASE WHEN LEFT(TRIM(ISNULL(@c_M_Zip,'')),1) IN ('7','8','9') THEN 'SI'
                                                                                           ELSE 'NI'
                                                                                           END
                       END
   --WL01 E
   SET @c_SQLJOIN = N' SELECT DISTINCT ' + CHAR(13)
                  + N'        '''', ST.StorerKey, OH.ShipperKey, ISNULL(TRIM(ST.Address1),''''),  ' + CHAR(13)   --4
                  + N'        LEFT(TRIM(ISNULL(ST.City,'''')) + '','' + TRIM(ISNULL(ST.[State],'''')) + '','' + TRIM(ISNULL(ST.Zip,'''')), 80), ' + CHAR(13)   --5
                  + N'        '''', '''', TRIM(ISNULL(ST.Country,'''')), TRIM(ISNULL(OH.Userdefine04,'''')), TRIM(ISNULL(OH.C_Company,'''')), ' + CHAR(13)   --10
                  + N'        TRIM(ISNULL(OH.C_Address1,'''')), '''', ' + CHAR(13) --12
                  + N'        LEFT(TRIM(ISNULL(OH.C_City,'''')) + '','' + TRIM(ISNULL(OH.C_State,'''')) + '','' + TRIM(ISNULL(OH.C_Zip,'''')), 80), ' + CHAR(13)   --13
                  + N'        '''', '''', TRIM(ISNULL(OH.C_Country,'''')), TRIM(PD.LottableValue), RIGHT(''0000'' + TRIM(ISNULL(OH.Userdefine05,'''')), 4), '   --18
                  + N'        TRIM(ISNULL(OH.M_Company,'''')), TRIM(ISNULL(OH.M_Address1,'''')), ' + CHAR(13) --20
                  + N'        '''', LEFT(TRIM(ISNULL(OH.M_City,'''')) + '','' + TRIM(@c_M_State), 80), '''', TRIM(ISNULL(OH.M_Zip,'''')), ' + CHAR(13)   --WL01   --24
                  + N'        TRIM(ISNULL(OH.BuyerPO,'''')), ' + CHAR(13) --25
                  + N'        TRIM(ISNULL(OH.UserDefine01,'''')), '''', CONVERT(NVARCHAR(10), ISNULL(OH.UserDefine06,''19000101''), 103), '''', ' + CHAR(13)   --29
                  + N'        CASE WHEN ISDATE(OH.UserDefine07) = 1 THEN ''ADV'' + FORMAT(OH.UserDefine07, ''ddMM'') ' + CHAR(13)
                  + N'                                              ELSE '''' END, ' + CHAR(13)   --30
                  + N'        ''554'' + TRIM(ISNULL(OH.C_Zip, '''')), ' + CHAR(13)   --31
                  + N'        RIGHT(TRIM(PD.LottableValue), 18), OH.TrackingNo, ''036'' + TRIM(ISNULL(OH.C_Zip, '''')), RIGHT(''0000'' + TRIM(ISNULL(OH.Userdefine04,'''')), 4), ' + CHAR(13)   --WL01
                  + N'        '''', '''', '''', '''', '''', ' + CHAR(13) --40
                  + N'        '''', '''', '''', '''', '''', '''', '''', '''', '''', '''', ' + CHAR(13) --50
                  + N'        '''', '''', '''', '''', '''', '''', '''', '''', PD.Storerkey, PD.LabelNo  ' + CHAR(13) --60
                  + N' FROM PackDetail PD (NOLOCK) ' + CHAR(13)
                  + N' JOIN PackHeader PH (NOLOCK) ON PH.PickSlipNo = PD.PickSlipNo ' + CHAR(13)
                  + N' JOIN ORDERS OH (NOLOCK) ON OH.OrderKey = PH.OrderKey ' + CHAR(13)
                  + N' JOIN SKU S (NOLOCK) ON S.StorerKey = PD.StorerKey AND S.SKU = PD.SKU ' + CHAR(13)
                  + N' JOIN STORER ST (NOLOCK) ON ST.StorerKey = OH.StorerKey ' + CHAR(13)
                  + N' WHERE PD.StorerKey = @c_Sparm1 AND PD.LabelNo = @c_Sparm2 '
    
   IF @b_debug = 1    
   BEGIN    
      PRINT @c_SQLJOIN    
   END    
 
   SET @c_SQL = ' INSERT INTO #Result (Col01,Col02,Col03,Col04,Col05, Col06,Col07,Col08,Col09' + CHAR(13)    
              + '                     ,Col10,Col11,Col12,Col13,Col14,Col15,Col16,Col17,Col18,Col19,Col20,Col21,Col22' + CHAR(13)    
              + '                     ,Col23,Col24,Col25,Col26,Col27,Col28,Col29,Col30,Col31,Col32,Col33,Col34' + CHAR(13)    
              + '                     ,Col35,Col36,Col37,Col38,Col39,Col40,Col41,Col42,Col43,Col44' + CHAR(13)    
              + '                     ,Col45,Col46,Col47,Col48,Col49,Col50,Col51,Col52,Col53,Col54' + CHAR(13)    
              + '                     ,Col55,Col56,Col57,Col58,Col59,Col60) '    
    
   SET @c_SQL = @c_SQL + @c_SQLJOIN    
    
   SET @c_ExecArguments = N'  @c_Sparm1         NVARCHAR(80)'     
                        + N' ,@c_Sparm2         NVARCHAR(80)'    
                        + N' ,@c_Sparm3         NVARCHAR(80)'     
                        + N' ,@c_Sparm4         NVARCHAR(80)'    
                        + N' ,@c_Sparm5         NVARCHAR(80)'
                        + N' ,@c_M_State        NVARCHAR(80)'   --WL01
    
   EXEC sp_executesql @c_SQL    
                    , @c_ExecArguments    
                    , @c_Sparm1    
                    , @c_Sparm2    
                    , @c_Sparm3    
                    , @c_Sparm4    
                    , @c_Sparm5    
                    , @c_M_State   --WL01

   EXIT_SP:    
    
   ;WITH CTE (Qty, MixedSKU) AS (
      SELECT SUM(PD.Qty)
           , CASE WHEN COUNT(DISTINCT PD.SKU) > 1 THEN 'MIXED' ELSE MAX(PD.SKU) END
      FROM PACKDETAIL PD (NOLOCK)
      WHERE PD.StorerKey = @c_Sparm1 AND PD.LabelNo = @c_Sparm2)
   UPDATE #Result
   SET Col29 = CTE.Qty
     , Col27 = CTE.MixedSKU
   FROM CTE
   WHERE Col59 = @c_Sparm1 AND Col60 = @c_Sparm2
    
   SELECT *    
   FROM #Result WITH (NOLOCK)    
END -- procedure 

GO