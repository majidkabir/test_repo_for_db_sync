SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/                       
/* Copyright: LFL                                                             */                       
/* Purpose: isp_BT_Bartender_CN_SHIPUCCLB3_STUSSY                             */                       
/*                                                                            */                       
/* Modifications log:                                                         */                       
/*                                                                            */                       
/* Date        Rev  Author     Purposes                                       */      
/* 09-Aug-2021 1.0  WLChooi    Created - DEVOPS Combine Script (WMS-17644)    */   
/* 17-Oct-2022 1.1  Mingle     WMS-20977 Add col14(ML01)								*/
/******************************************************************************/                      
                        
CREATE PROC [dbo].[isp_BT_Bartender_CN_SHIPUCCLB3_STUSSY]                            
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
                                         
   DECLARE @c_SQL               NVARCHAR(4000)  
         , @d_Trace_StartTime   DATETIME         
         , @d_Trace_EndTime     DATETIME        
         , @c_Trace_ModuleName  NVARCHAR(20)         
         , @d_Trace_Step1       DATETIME        
         , @c_Trace_Step1       NVARCHAR(20)       
         , @c_UserName          NVARCHAR(20)               
         , @c_ExecArguments     NVARCHAR(4000)
         , @c_SQLJOIN           NVARCHAR(MAX)
         , @c_Storerkey         NVARCHAR(15)
         , @c_CheckConso        NVARCHAR(10) = 'N'
         , @c_JoinStatement     NVARCHAR(MAX)
         , @n_SumPickQty        INT = 0
         , @n_SumPackQty        INT = 0
         , @c_LastCtn           NVARCHAR(10) = 'N'
         , @c_MaxCtn            NVARCHAR(10) = ''

   DECLARE @c_Col01             NVARCHAR(80)
         , @c_Col02             NVARCHAR(80)
         , @c_Col03             NVARCHAR(80)
         , @c_Col04             NVARCHAR(80)      
         , @c_Col05             NVARCHAR(80)
         , @c_Col06             NVARCHAR(80)
         , @c_Col07             NVARCHAR(80)
         , @c_Col08             NVARCHAR(80)
         , @c_Col09             NVARCHAR(80)
         , @c_Col10             NVARCHAR(80)
         , @c_Col11             NVARCHAR(80)

   SET @d_Trace_StartTime = GETDATE()        
   SET @c_Trace_ModuleName = ''        
              
    -- SET RowNo = 0  
   SET @c_SQL = ''                 
   SET @c_SQLJOIN = ''   
   SET @c_ExecArguments = ''

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

   --Discrete  
   SELECT TOP 1 @c_Col01     = LEFT(
                               CASE WHEN ISNULL(FACILITY.Address1,'') = '' THEN '' ELSE TRIM(FACILITY.Address1) + ', ' END + 
                               CASE WHEN ISNULL(FACILITY.Address2,'') = '' THEN '' ELSE TRIM(FACILITY.Address2) + ', ' END + 
                               CASE WHEN ISNULL(FACILITY.City,'') = ''     THEN '' ELSE TRIM(FACILITY.City)     + ', ' END + 
                               CASE WHEN ISNULL(FACILITY.[State],'') = ''  THEN '' ELSE TRIM(FACILITY.[State])  + ', ' END + 
                               CASE WHEN ISNULL(FACILITY.Country,'') = ''  THEN '' ELSE TRIM(FACILITY.Country)  + ', ' END + 
                               CASE WHEN ISNULL(FACILITY.Zip,'') = ''      THEN '' ELSE TRIM(FACILITY.Zip) END, 80) 
              , @c_Col02     = ISNULL(ORDERS.C_contact1,'')
              , @c_Col03     = ISNULL(ORDERS.C_Company,'')
              , @c_Col04     = LEFT(
                               CASE WHEN TRIM(ISNULL(ORDERS.C_Address1,'')) = '' THEN '' ELSE TRIM(ORDERS.C_Address1) + ', ' END + 
                               CASE WHEN TRIM(ISNULL(ORDERS.C_Address2,'')) = '' THEN '' ELSE TRIM(ORDERS.C_Address2) + ', ' END + 
                               CASE WHEN TRIM(ISNULL(ORDERS.C_Address3,'')) = '' THEN '' ELSE TRIM(ORDERS.C_Address3) + ', ' END + 
                               CASE WHEN TRIM(ISNULL(ORDERS.C_Address4,'')) = '' THEN '' ELSE TRIM(ORDERS.C_Address4) + ', ' END + 
                               CASE WHEN TRIM(ISNULL(ORDERS.C_City,'') )= ''     THEN '' ELSE TRIM(ORDERS.C_City)     + ', ' END + 
                               CASE WHEN TRIM(ISNULL(ORDERS.C_State,'')) = ''    THEN '' ELSE TRIM(ORDERS.C_State)    + ', ' END + 
                               CASE WHEN TRIM(ISNULL(ORDERS.C_Country,'')) = ''  THEN '' ELSE TRIM(ORDERS.C_Country)  + ', ' END + 
                               CASE WHEN TRIM(ISNULL(ORDERS.C_Zip,'')) = ''      THEN '' ELSE TRIM(ORDERS.C_Zip) END , 80) 
              , @c_Col05     = ISNULL(ORDERS.C_Zip,'')
              , @c_Col06     = ISNULL(ORDERS.ConsigneeKey,'')
              , @c_Col07     = ISNULL(ORDERS.PmtTerm,'')
              , @c_Col08     = ISNULL(ORDERS.BuyerPO,'')
              , @c_Col09     = ISNULL(ORDERS.DischargePlace,'')
              , @c_Col10     = ISNULL(ORDERS.MBOLKey,'')
              , @c_Col11     = ISNULL(ORDERS.ExternOrderKey,'')
              , @c_Storerkey = ORDERS.Storerkey
   FROM PACKHEADER (NOLOCK)  
   JOIN ORDERS (NOLOCK) ON ORDERS.ORDERKEY = PACKHEADER.ORDERKEY 
   JOIN FACILITY (NOLOCK) ON FACILITY.Facility = ORDERS.Facility
   WHERE PACKHEADER.Pickslipno = @c_Sparm01 
   
   SELECT @n_SumPickQty = SUM(PICKDETAIL.Qty)
   FROM PICKDETAIL (NOLOCK) 
   JOIN PACKHEADER (NOLOCK) ON PACKHEADER.OrderKey = PICKDETAIL.OrderKey
   WHERE PACKHEADER.PickSlipNo = @c_Sparm01
  
   IF ISNULL(@c_Storerkey,'') = ''  
   BEGIN  
      --Conso  
      SELECT TOP 1 @c_Col01     = LEFT(
                                  CASE WHEN ISNULL(FACILITY.Address1,'') = '' THEN '' ELSE TRIM(FACILITY.Address1) + ', ' END + 
                                  CASE WHEN ISNULL(FACILITY.Address2,'') = '' THEN '' ELSE TRIM(FACILITY.Address2) + ', ' END + 
                                  CASE WHEN ISNULL(FACILITY.City,'') = ''     THEN '' ELSE TRIM(FACILITY.City)     + ', ' END + 
                                  CASE WHEN ISNULL(FACILITY.[State],'') = ''  THEN '' ELSE TRIM(FACILITY.[State])  + ', ' END + 
                                  CASE WHEN ISNULL(FACILITY.Country,'') = ''  THEN '' ELSE TRIM(FACILITY.Country)  + ', ' END + 
                                  CASE WHEN ISNULL(FACILITY.Zip,'') = ''      THEN '' ELSE TRIM(FACILITY.Zip) END, 80) 
                 , @c_Storerkey = ORDERS.Storerkey
                 , @c_Col02     = ISNULL(ORDERS.C_contact1,'')
                 , @c_Col03     = ISNULL(ORDERS.C_Company,'')
                 , @c_Col04     = LEFT(
                                  CASE WHEN TRIM(ISNULL(ORDERS.C_Address1,'')) = '' THEN '' ELSE TRIM(ORDERS.C_Address1) + ', ' END + 
                                  CASE WHEN TRIM(ISNULL(ORDERS.C_Address2,'')) = '' THEN '' ELSE TRIM(ORDERS.C_Address2) + ', ' END + 
                                  CASE WHEN TRIM(ISNULL(ORDERS.C_Address3,'')) = '' THEN '' ELSE TRIM(ORDERS.C_Address3) + ', ' END + 
                                  CASE WHEN TRIM(ISNULL(ORDERS.C_Address4,'')) = '' THEN '' ELSE TRIM(ORDERS.C_Address4) + ', ' END + 
                                  CASE WHEN TRIM(ISNULL(ORDERS.C_City,'') )= ''     THEN '' ELSE TRIM(ORDERS.C_City)     + ', ' END + 
                                  CASE WHEN TRIM(ISNULL(ORDERS.C_State,'')) = ''    THEN '' ELSE TRIM(ORDERS.C_State)    + ', ' END + 
                                  CASE WHEN TRIM(ISNULL(ORDERS.C_Country,'')) = ''  THEN '' ELSE TRIM(ORDERS.C_Country)  + ', ' END + 
                                  CASE WHEN TRIM(ISNULL(ORDERS.C_Zip,'')) = ''      THEN '' ELSE TRIM(ORDERS.C_Zip) END , 80) 
                 , @c_Col05     = ISNULL(ORDERS.C_Zip,'')
                 , @c_Col06     = ISNULL(ORDERS.ConsigneeKey,'')
                 , @c_Col07     = ISNULL(ORDERS.PmtTerm,'')
                 , @c_Col08     = ISNULL(ORDERS.BuyerPO,'')
                 , @c_Col09     = ISNULL(ORDERS.DischargePlace,'')
                 , @c_Col10     = ISNULL(ORDERS.MBOLKey,'')
                 , @c_Col11     = ISNULL(ORDERS.ExternOrderKey,'')
      FROM PACKHEADER (NOLOCK)  
      JOIN LOADPLANDETAIL (NOLOCK) ON PACKHEADER.LOADKEY = LOADPLANDETAIL.LOADKEY  
      JOIN ORDERS (NOLOCK) ON ORDERS.ORDERKEY = LOADPLANDETAIL.ORDERKEY  
      JOIN FACILITY (NOLOCK) ON FACILITY.Facility = ORDERS.Facility
      WHERE PACKHEADER.Pickslipno = @c_Sparm01  
      
      SELECT @n_SumPickQty = SUM(PICKDETAIL.Qty)
      FROM PICKDETAIL (NOLOCK) 
      JOIN LOADPLANDETAIL (NOLOCK) ON LoadPlanDetail.OrderKey = PICKDETAIL.OrderKey
      JOIN PACKHEADER (NOLOCK) ON PACKHEADER.LoadKey = LoadPlanDetail.LoadKey
      WHERE PACKHEADER.PickSlipNo = @c_Sparm01

      IF ISNULL(@c_Storerkey,'') <> ''  
         SET @c_CheckConso = 'Y'  
      ELSE  
         GOTO EXIT_SP  
   END  
   
   SET @c_JoinStatement = N' JOIN ORDERS OH (NOLOCK) ON PH.ORDERKEY = OH.ORDERKEY ' + CHAR(13)  
     
   IF @c_CheckConso = 'Y'  
   BEGIN  
      SET @c_JoinStatement = N' JOIN LOADPLANDETAIL LPD (NOLOCK) ON PH.LOADKEY = LPD.LOADKEY ' + CHAR(13)  
                            + ' JOIN ORDERS OH (NOLOCK) ON OH.ORDERKEY = LPD.ORDERKEY ' + CHAR(13)  
   END 

   SELECT @n_SumPackQty = SUM(PACKDETAIL.Qty)
   FROM PACKDETAIL (NOLOCK) 
   WHERE PACKDETAIL.PickSlipNo = @c_Sparm01

   IF @n_SumPackQty = @n_SumPickQty
   BEGIN 
      SET @c_LastCtn = 'Y'
      
      SELECT @c_MaxCtn = MAX(CartonNo)
      FROM PACKDETAIL (NOLOCK)
      WHERE PickSlipNo = @c_Sparm01
   END

   SET @c_SQLJOIN = + ' SELECT DISTINCT @c_Col01, @c_Col02, @c_Col03, @c_Col04, @c_Col05, ' + CHAR(13)   --5
                    + ' @c_Col06, @c_Col07, @c_Col08, @c_Col09, @c_Col10, '   + CHAR(13)   --10 
                    + ' @c_Col11, CASE WHEN @c_LastCtn = ''Y'' THEN CAST(PD.CartonNo AS NVARCHAR) + ''/'' + @c_MaxCtn ELSE CAST(PD.CartonNo AS NVARCHAR) END, '   --12
                    + ' PD.LabelNo, PI.CartonType, '''', '''', '''', '''', '''', '''', ' + CHAR(13)  --20	--ML01     
                    + ' '''', '''', '''', '''', '''', '''', '''', '''', '''', '''', ' + CHAR(13)  --30     
                    + ' '''', '''', '''', '''', '''', '''', '''', '''', '''', '''', ' + CHAR(13)  --40        
                    + ' '''', '''', '''', '''', '''', '''', '''', '''', '''', '''', ' + CHAR(13)  --50                           
                    + ' '''', '''', '''', '''', '''', '''', '''', '''', '''', @c_Sparm01 ' + CHAR(13)  --60                
                    + ' FROM PACKDETAIL PD (NOLOCK) ' + CHAR(13)
						  + ' JOIN PACKINFO PI (NOLOCK) ON PI.pickslipno = PD.pickslipno and PI.cartonno=PD.cartonno '	--ML01
                    + ' WHERE PD.Pickslipno = @c_Sparm01 ' + CHAR(13)  
                    + ' AND PD.CartonNo = CAST(@c_Sparm02 AS INT) '

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
      
   SET @c_ExecArguments = N'  @c_Sparm01          NVARCHAR(80) '          
                         + ', @c_Sparm02          NVARCHAR(80) '      
                         + ', @c_Sparm03          NVARCHAR(80) ' 
                         + ', @c_Sparm04          NVARCHAR(80) ' 
                         + ', @c_Sparm05          NVARCHAR(80) ' 
                         + ', @c_Col01            NVARCHAR(80) '  
                         + ', @c_Col02            NVARCHAR(80) '  
                         + ', @c_Col03            NVARCHAR(80) '  
                         + ', @c_Col04            NVARCHAR(80) '  
                         + ', @c_Col05            NVARCHAR(80) '  
                         + ', @c_Col06            NVARCHAR(80) '  
                         + ', @c_Col07            NVARCHAR(80) '  
                         + ', @c_Col08            NVARCHAR(80) '  
                         + ', @c_Col09            NVARCHAR(80) '  
                         + ', @c_Col10            NVARCHAR(80) '  
                         + ', @c_Col11            NVARCHAR(80) '  
                         + ', @c_LastCtn          NVARCHAR(80) '
                         + ', @c_MaxCtn           NVARCHAR(80) '
                                
   EXEC sp_ExecuteSql     @c_SQL           
                        , @c_ExecArguments          
                        , @c_Sparm01         
                        , @c_Sparm02     
                        , @c_Sparm03   
                        , @c_Sparm04   
                        , @c_Sparm05   
                        , @c_Col01
                        , @c_Col02
                        , @c_Col03
                        , @c_Col04
                        , @c_Col05
                        , @c_Col06
                        , @c_Col07
                        , @c_Col08
                        , @c_Col09
                        , @c_Col10
                        , @c_Col11
                        , @c_LastCtn
                        , @c_MaxCtn
              
   IF @b_debug = 1              
   BEGIN                
      PRINT @c_SQL                
   END        
                 
   SELECT * FROM #Result (nolock)            
                  
EXIT_SP:                 
                              
END -- procedure

GO