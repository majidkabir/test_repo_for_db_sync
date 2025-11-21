SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/    
/* Copyright: LFL                                                             */    
/* Purpose: isp_BT_Bartender_AU_VASXDLBL01_JJ                                 */    
/*                                                                            */    
/* Modifications log:                                                         */    
/*                                                                            */    
/* Date        Rev  Author     Purposes                                       */    
/* 27-Mar-2023 1.0  WLChooi    Created (WMS-21985)                            */    
/* 27-Mar-2023 1.0  WLChooi    DevOps Combine Script                          */    
/******************************************************************************/    
    
CREATE   PROC [dbo].[isp_BT_Bartender_AU_VASXDLBL01_JJ]
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

   SET @c_SQLJOIN = N' SELECT DISTINCT ' + CHAR(13)
                  + N'        '''', ST.Company, ISNULL(TRIM(ST.Address1),''''), LEFT(TRIM(ISNULL(ST.City,'''')) + '','' + TRIM(ISNULL(ST.[State],'''')), 80), ' + CHAR(13)   --4
                  + N'        TRIM(ISNULL(ST.Zip,'''')), ' + CHAR(13)   --5
                  + N'        TRIM(ISNULL(OH.C_Company,'''')), TRIM(ISNULL(OH.C_Address1,'''')),  ' + CHAR(13)   --7
                  + N'        TRIM(ISNULL(OH.C_City,'''')) + '','' + TRIM(ISNULL(OH.C_State,'''')), TRIM(ISNULL(OH.C_Zip,'''')), TRIM(ISNULL(OH.C_Country,'''')), ' + CHAR(13) --10
                  + N'        OH.Userdefine04, TRIM(PD.LottableValue), TRIM(ISNULL(OH.BuyerPO,'''')), '''', ' + CHAR(13)   --14
                  + N'        RIGHT(TRIM(PD.LottableValue), 18), ' + CHAR(13)   --15
                  + N'        OH.Shipperkey, OH.TrackingNo, ' + CHAR(13)
                  + N'        CASE WHEN LEN(TRIM(OH.UserDefine04)) > 2 THEN ''>6'' + SUBSTRING(OH.UserDefine04, 3, LEN(OH.UserDefine04) - 2) ELSE '''' END, ' + CHAR(13)
                  + N'        LEFT(TRIM(OH.UserDefine04), 2), '''', '   --20
                  + N'        '''', '''', '''', '''', '''', '''', '''', '''', '''', '''', ' + CHAR(13) --30
                  + N'        '''', '''', '''', '''', '''', '''', '''', '''', '''', '''', ' + CHAR(13) --40
                  + N'        '''', '''', '''', '''', '''', '''', '''', '''', '''', '''', ' + CHAR(13) --50
                  + N'        '''', '''', '''', '''', '''', '''', '''', '''', PD.Storerkey, PD.LabelNo  ' + CHAR(13) --60
                  + N' FROM PackDetail PD (NOLOCK) ' + CHAR(13)
                  + N' JOIN PackHeader PH (NOLOCK) ON PH.PickSlipNo = PD.PickSlipNo ' + CHAR(13)
                  + N' JOIN ORDERS OH (NOLOCK) ON OH.OrderKey = PH.OrderKey ' + CHAR(13)
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
    
   EXEC sp_executesql @c_SQL    
                    , @c_ExecArguments    
                    , @c_Sparm1    
                    , @c_Sparm2    
                    , @c_Sparm3    
                    , @c_Sparm4    
                    , @c_Sparm5    

   EXIT_SP:    
    
   SELECT *    
   FROM #Result WITH (NOLOCK)    
END -- procedure 

GO