SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/******************************************************************************/                   
/* Copyright: LFL                                                             */                   
/* Purpose: HK_Nike Baozun SF Label Bartender                                 */ 
/*          isp_Bartender_HK_SHIPSFBZLB_01                                    */                        
/*                                                                            */                   
/* Modifications log:                                                         */                   
/*                                                                            */                   
/* Date       Rev  Author     Purposes                                        */                   
/* 2020-12-23 1.0  WLChooi    Created (WMS-15889)                             */ 
/* 2021-02-24 1.1  WLChooi    WMS-15889 - Add Col33 (WL01)                    */    
/* 2021-03-19 1.2  WLChooi    WMS-15889 - Add Col34 (WL02)                    */   
/* 2021-04-02 1.3  CSCHONG    Update trackingno field mapping (CS01)          */            
/******************************************************************************/                                     
CREATE PROC [dbo].[isp_Bartender_HK_SHIPSFBZLB_01]                        
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
      @n_copy            INT,                      
      @c_ExternOrderKey  NVARCHAR(10),                
      @c_Deliverydate    DATETIME,                
      @n_intFlag         INT,       
      @n_CntRec          INT,      
      @c_SQL             NVARCHAR(4000),          
      @c_SQLSORT         NVARCHAR(4000),          
      @c_SQLJOIN         NVARCHAR(4000),
      @c_WhereCondition  NVARCHAR(4000) = ''        
      
   DECLARE  @d_Trace_StartTime  DATETIME,     
            @d_Trace_EndTime    DATETIME,    
            @c_Trace_ModuleName NVARCHAR(20),     
            @d_Trace_Step1      DATETIME,     
            @c_Trace_Step1      NVARCHAR(20),    
            @c_UserName         NVARCHAR(20),  
            @c_ExecArguments    NVARCHAR(4000)       
    
   SET @d_Trace_StartTime = GETDATE()    
   SET @c_Trace_ModuleName = ''    
          
    -- SET RowNo = 0               
   SET @c_SQL = ''         
                
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
   
   SET @c_WhereCondition = ''
   
   IF ISNULL(@c_Sparm01,'') <> ''
      SET @c_WhereCondition = @c_WhereCondition + ' AND PH.Pickslipno = @c_Sparm01 '
      
   IF ISNULL(@c_Sparm02,'') <> ''
      SET @c_WhereCondition = @c_WhereCondition + ' AND PD.LabelNo = @c_Sparm02 '
      
   IF ISNULL(@c_Sparm03,'') <> ''
      SET @c_WhereCondition = @c_WhereCondition + ' AND PH.Storerkey = @c_Sparm03 '
      
   IF ISNULL(@c_Sparm04,'') <> ''
      SET @c_WhereCondition = @c_WhereCondition + ' AND OH.Orderkey = @c_Sparm04 '
      
   IF ISNULL(@c_Sparm05,'') <> ''
      SET @c_WhereCondition = @c_WhereCondition + ' AND PD.CartonNo = @c_Sparm05 '
      
   SET @c_SQLJOIN = + ' SELECT DISTINCT OH.Orderkey, OH.Externorderkey, OH.M_Company, OH.Userdefine03, OH.Salesman,'+ CHAR(13) +     --5       
                    + ' OH.DeliveryPlace, OH.C_Contact1, OH.C_Zip, OH.C_Phone1, OH.C_Phone2, '+ CHAR(13) +   --10    
                    + ' OH.C_State, OH.C_City, OH.C_Address1, OH.C_Address2, OH.C_Address3,'  + CHAR(13) +   --15         
                    + ' OH.C_Address4, F.Contact1, F.Phone1, F.Address1, F.Address2,'+ CHAR(13) +   --20        
                    + ' F.Address3, F.Country, PD.Cartonno, CONVERT(NVARCHAR(30), GETDATE(), 120),'+ CHAR(13) +   --24  
                    + ' CONVERT(NVARCHAR(30), DATEADD(d, 1, GETDATE()), 120),'+ CHAR(13) +   --25   
                    + ' CASE WHEN PD.CartonNo > ''1'' THEN OH.trackingno ELSE '''' END, ' + CHAR(13) +   --26                      --CS01
                    + ' CASE WHEN PD.CartonNo = ''1'' THEN OH.trackingno ELSE ISNULL(CT.TrackingNo,'''') END,'+ CHAR(13) +   --27  --CS01
                    + ' ISNULL(CL.Long,''''), SUM(PD.Qty), MAX(PD.CartonNo),'   + CHAR(13) +   --30
                    + ' ISNULL(CL1.Long,''''),CONVERT(NVARCHAR(16), OH.DeliveryDate, 120),CASE WHEN LTRIM(RTRIM(ISNULL(OH.SpecialHandling,''''))) = ''Q'' THEN ''QS'' ELSE '''' END, ' + CHAR(13) +   --33   --WL01
                    + ' CASE WHEN OH.[Type] = ''COD'' THEN ''COD[HKD'' + CAST(OH.InvoiceAmount AS NVARCHAR(20)) + '']'' ELSE '''' END,'''','''','''','''','''','''','+ CHAR(13) +   --40   --WL01   --WL02 
                    + ' '''','''','''','''','''','''','''','''','''','''','+ CHAR(13) +   --50         
                    + ' '''','''','''','''','''','''','''','''','''',PH.PickSlipNo '+ CHAR(13) +   --60    
                    + ' FROM ORDERS OH (NOLOCK) '   + CHAR(13) + 
                    + ' JOIN FACILITY F (NOLOCK)ON OH.Facility = F.Facility '   + CHAR(13) + 
                    + ' JOIN PACKHEADER PH (NOLOCK) ON PH.OrderKey = OH.OrderKey '   + CHAR(13) + 
                    + ' JOIN PACKDETAIL PD (NOLOCK) ON PH.PickSlipNo = PD.Pickslipno '   + CHAR(13) + 
                    + ' LEFT JOIN CODELKUP CL (NOLOCK) ON CL.LISTNAME = ''NIKESoldto'' AND CL.Short = OH.B_Company '   + CHAR(13) +
                    + '                               AND CL.Storerkey = OH.StorerKey '   + CHAR(13) + 
                    + ' LEFT JOIN CartonTrack CT (NOLOCK)ON CT.LabelNo = OH.OrderKey AND CT.KeyName = ''NIKEO2SUB'' '   + CHAR(13) +
                    + '                                 AND RIGHT(CarrierRef1, 1) = PD.Cartonno '   + CHAR(13) +
                    + '                                 AND CT.CarrierName = OH.ShipperKey '   + CHAR(13) + 
                    + ' LEFT JOIN CODELKUP CL1 (NOLOCK)ON CL1.LISTNAME = ''NKSFLBLTYP'' AND CL1.Code = OH.DischargePlace '   + CHAR(13) +
                    + '                               AND CL1.Storerkey = OH.Storerkey '   + CHAR(13) +
                    + ' WHERE 1=1 '   + CHAR(13) + 
                    + @c_WhereCondition  
                    + ' GROUP BY OH.Orderkey, OH.Externorderkey, OH.M_Company, OH.Userdefine03, OH.Salesman,'+ CHAR(13) +     
                    + '          OH.DeliveryPlace, OH.C_Contact1, OH.C_Zip, OH.C_Phone1, OH.C_Phone2, '+ CHAR(13) +  
                    + '          OH.C_State, OH.C_City, OH.C_Address1, OH.C_Address2, OH.C_Address3,'  + CHAR(13) +        
                    + '          OH.C_Address4, F.Contact1, F.Phone1, F.Address1, F.Address2,'+ CHAR(13) +    
                    + '          F.Address3, F.Country, PD.Cartonno,'+ CHAR(13) +
                    + '          OH.trackingno, CASE WHEN PD.CartonNo = ''1'' THEN OH.trackingno ELSE ISNULL(CT.TrackingNo,'''') END,'+ CHAR(13) +      --CS01
                    + '          ISNULL(CL.Long,''''), PH.PickSlipNo,ISNULL(CL1.Long,''''), CONVERT(NVARCHAR(16), OH.DeliveryDate, 120), '+ CHAR(13) +   --WL01
                    + '          CASE WHEN LTRIM(RTRIM(ISNULL(OH.SpecialHandling,''''))) = ''Q'' THEN ''QS'' ELSE '''' END, '   --WL01
                    + '          CASE WHEN OH.[Type] = ''COD'' THEN ''COD[HKD'' + CAST(OH.InvoiceAmount AS NVARCHAR(20)) + '']'' ELSE '''' END '   --WL02
            
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
  
   SET @c_ExecArguments = N'@c_Sparm01       NVARCHAR(80),'     
                        +  '@c_Sparm02       NVARCHAR(80),'  
                        +  '@c_Sparm03       NVARCHAR(80),' 
                        +  '@c_Sparm04       NVARCHAR(80),' 
                        +  '@c_Sparm05       NVARCHAR(80) ' 
    
      
   SET @c_SQL = @c_SQL + @c_SQLJOIN   
  
   EXEC sp_ExecuteSql @c_SQL     
                    , @c_ExecArguments    
                    , @c_Sparm01      
                    , @c_Sparm02      
                    , @c_Sparm03
                    , @c_Sparm04  
                    , @c_Sparm05     
                  
          
   IF @b_debug=1   
   BEGIN            
      PRINT @c_SQL                
      SELECT * FROM #Result (nolock)          
   END               
 
   SELECT * FROM #Result (nolock)     
              
EXIT_SP:      
    
   SET @d_Trace_EndTime = GETDATE()    
   SET @c_UserName = SUSER_SNAME()    
       
   --EXEC isp_InsertTraceInfo     
   --   @c_TraceCode = 'BARTENDER',    
   --   @c_TraceName = 'isp_Bartender_HK_SHIPSFBZLB_01',    
   --   @c_starttime = @d_Trace_StartTime,    
   --   @c_endtime = @d_Trace_EndTime,    
   --   @c_step1 = @c_UserName,    
   --   @c_step2 = '',    
   --   @c_step3 = '',    
   --   @c_step4 = '',    
   --   @c_step5 = '',    
   --   @c_col1 = @c_Sparm01,     
   --   @c_col2 = @c_Sparm02,    
   --   @c_col3 = @c_Sparm03,    
   --   @c_col4 = @c_Sparm04,    
   --   @c_col5 = @c_Sparm05,    
   --   @b_Success = 1,    
   --   @n_Err = 0,    
   --   @c_ErrMsg = ''                
                         
END -- procedure     

GO