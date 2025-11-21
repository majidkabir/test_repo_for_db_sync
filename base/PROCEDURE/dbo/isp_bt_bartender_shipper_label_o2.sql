SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/******************************************************************************/                       
/* Copyright: LFL                                                             */                       
/* Purpose: isp_BT_Bartender_Shipper_Label_O2                                 */                       
/*                                                                            */                       
/* Modifications log:                                                         */                       
/*                                                                            */                       
/* Date       Rev  Author    Purposes                                         */      
/*08-Dec-2020 1.0  WLChooi   Created (WMS-15823)                              */ 
/*11-Feb-2021 1.1  WLChooi   WMS-16339 - Add Col42 to Col47 (WL01)            */   
/*02-Apr-2021 1.2  CSCHONG   WMS-16024 PB-Standardize TrackingNo (CS01)       */  
/*21-Jun-2021 1.3  WLChooi   WMS-17325 - Modify Col41 & Add Col48 (WL02)      */ 
/*28-Oct-2021 1.4  Mingle    WMS-18203 - Modify Col39(ML01)                   */ 
/*28-Oct-2021 1.4  Mingle    DevOps Combine Script                            */
/******************************************************************************/                      
                        
CREATE PROC [dbo].[isp_BT_Bartender_Shipper_Label_O2]                            
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
                                    
   DECLARE @c_SQL             NVARCHAR(4000)           
          
   DECLARE @d_Trace_StartTime   DATETIME,         
           @d_Trace_EndTime     DATETIME,        
           @c_Trace_ModuleName  NVARCHAR(20),         
           @d_Trace_Step1       DATETIME,         
           @c_Trace_Step1       NVARCHAR(20),        
           @c_UserName          NVARCHAR(20),               
           @c_ExecArguments     NVARCHAR(4000),
           @c_SQLJOIN           NVARCHAR(MAX),
           @n_SumQty            INT = 0,
           @n_SumWeight         FLOAT = 0.00,
           @c_Shipperkey        NVARCHAR(50),
           @c_PIFTrackingno      NVARCHAR(40)

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

   --WL02 - S
   SELECT @c_Shipperkey = OH.Shipperkey
   FROM ORDERS OH (NOLOCK)
   WHERE OH.OrderKey = @c_Sparm02


   IF @c_Shipperkey = 'SF'
   BEGIN
      SET @c_SQLJOIN = +' SELECT DISTINCT OH.Loadkey, OH.Orderkey, OH.ExternOrderkey, OH.[Type], OH.Shipperkey, ' + CHAR(13)   --5             
                       +' OH.Facility, OH.Consigneekey, OH.C_Company, ISNULL(OH.C_Address1,''''), ISNULL(OH.C_Address2,''''), ' + CHAR(13)   --10    
                       +' ISNULL(OH.C_Address3,''''), ISNULL(OH.C_Address4,''''), ISNULL(OH.C_State,''''), ISNULL(OH.C_City,''''),' + CHAR(13)   --14 
                       +' ISNULL(OH.C_Zip,''''), ISNULL(OH.C_Contact1,''''), ISNULL(OH.C_Phone1,''''), ISNULL(OH.C_Phone2,''''), ISNULL(OH.M_Company,''''), ' + CHAR(13) --19  
                       +' ISNULL(OH.B_Company,''''), ISNULL(OH.Userdefine02,''''), ISNULL(OH.Userdefine03,''''), ISNULL(OH.trackingno,''''), ISNULL(OH.Userdefine05,''''),  ' + CHAR(13   )--24     
                       +' OH.Userdefine06, OH.InvoiceAmount, ISNULL(F.Contact1,''''), ISNULL(F.Contact2,''''), ISNULL(F.Phone1,''''), ISNULL(F.Phone2,''''),  ' + CHAR(13)   --30 
                       +' LTRIM(RTRIM(ISNULL(F.Address1,''''))) + '' '' + LTRIM(RTRIM(ISNULL(F.Address2,''''))) + '' '' + LTRIM(RTRIM(ISNULL(F.Address3,''''))), ' + CHAR(13)   --31 
                       +' '''', '''', ISNULL(OH.DeliveryPlace,''''), ISNULL(OH.DeliveryNote,''''), ISNULL(OH.B_Address1,''''), ISNULL(OH.B_Zip,''''), ' + CHAR(13)   --37
                       +' ISNULL(CL1.UDF01,''''),'''' , ISNULL(CL2.Long,''''), ' + CHAR(13)  --40 
                       --WL01 S 
                       +N'CASE WHEN ISNULL(CL2.Long,'''') = ''OUTLET'' THEN N''顺丰标快'' '   
                       +N'                                             ELSE CASE WHEN ISNULL(OH.B_Zip,'''') = ''1'' THEN N''顺丰次日'' '
                       +N'                                                       WHEN ISNULL(OH.B_Zip,'''') = ''2'' THEN N''顺丰隔日'' '
                       +N'                                                       WHEN ISNULL(OH.B_Zip,'''') = ''5'' THEN N''顺丰次晨'' '
                       +N'                                                       WHEN ISNULL(OH.B_Zip,'''') = ''6'' THEN N''顺丰即日'' '
                       +N'                                                       ELSE N'''' END '
                       +N'                                             END, '   --41
                       --WL02 E
                       +' SUBSTRING(ISNULL(CL2.Notes,''''), 1, 80), SUBSTRING(ISNULL(CL2.[Description],''''), 1, 80), ISNULL(CL2.UDF01,''''), ISNULL(CL2.UDF02,''''), ' + CHAR(13)  --45     
                       +' SUBSTRING(LTRIM(RTRIM(ISNULL(OH.C_State,''''))) + LTRIM(RTRIM(ISNULL(OH.C_City,''''))) + LTRIM(RTRIM(ISNULL(OH.C_Address1,''''))) + ' +
                       +' LTRIM(RTRIM(ISNULL(OH.C_Address2,''''))) + LTRIM(RTRIM(ISNULL(OH.C_Address3,''''))) + LTRIM(RTRIM(ISNULL(OH.C_Address4,''''))), 1, 80), ' + CHAR(13)   --46
                       +' ISNULL(OH.DeliveryNote,''''), ISNULL(CL2.UDF03,''''), '''', '''', ' + CHAR(13)  --50                         
                       +' '''', '''', '''', '''', '''', '''', '''', @c_Sparm01, @c_Sparm02, @c_Sparm05 ' + CHAR(13)  --60                
                       +' FROM ORDERS OH (NOLOCK) ' + CHAR(13)
                       +' JOIN FACILITY F (NOLOCK) ON OH.Facility = F.Facility ' + CHAR(13)
                       +' LEFT JOIN CODELKUP CL1 (NOLOCK) ON CL1.Listname = ''WSCourier'' AND CL1.Short = OH.ShipperKey ' + CHAR(13)
                       +'                                AND CL1.Storerkey = OH.StorerKey ' + CHAR(13)
                       +' LEFT JOIN CODELKUP CL2 (NOLOCK) ON CL2.Listname = ''NIKESoldTo'' AND CL2.Short = OH.B_Company ' + CHAR(13)
                       +' LEFT JOIN CartonTrack CT2 (NOLOCK) ON CT2.LabelNo = OH.OrderKey AND CT2.KeyName = ''NIKEO2SUB'' AND SUBSTRING(CT2.CarrierRef1, 11, 3) = @c_Sparm05 ' + CHAR(13)
                       +'                                   AND CT2.CarrierName = OH.ShipperKey ' + CHAR(13)  
                       +' WHERE OH.LoadKey = @c_Sparm01 '+ CHAR(13)              
                       +' AND OH.OrderKey = @c_Sparm02 '
   END
   ELSE   
   BEGIN   --WL02 E
      SET @c_SQLJOIN = +' SELECT DISTINCT OH.Loadkey, OH.Orderkey, OH.ExternOrderkey, OH.[Type], OH.Shipperkey, ' + CHAR(13)   --5             
                       +' OH.Facility, OH.Consigneekey, OH.C_Company, ISNULL(OH.C_Address1,''''), ISNULL(OH.C_Address2,''''), ' + CHAR(13)   --10    
                       +' ISNULL(OH.C_Address3,''''), ISNULL(OH.C_Address4,''''), ISNULL(OH.C_State,''''), ISNULL(OH.C_City,''''),' + CHAR(13)   --14 
                       +' ISNULL(OH.C_Zip,''''), ISNULL(OH.C_Contact1,''''), ISNULL(OH.C_Phone1,''''), ISNULL(OH.C_Phone2,''''), ISNULL(OH.M_Company,''''), ' + CHAR(13) --19  
                       +' ISNULL(OH.B_Company,''''), ISNULL(OH.Userdefine02,''''), ISNULL(OH.Userdefine03,''''), ISNULL(OH.trackingno,''''), ISNULL(OH.Userdefine05,''''),  ' + CHAR(13   )--24 --CS01     
                       +' OH.Userdefine06, OH.InvoiceAmount, ISNULL(F.Contact1,''''), ISNULL(F.Contact2,''''), ISNULL(F.Phone1,''''), ISNULL(F.Phone2,''''),  ' + CHAR(13)   --30 
                       +' LTRIM(RTRIM(ISNULL(F.Address1,''''))) + '' '' + LTRIM(RTRIM(ISNULL(F.Address2,''''))) + '' '' + LTRIM(RTRIM(ISNULL(F.Address3,''''))), ' + CHAR(13)   --31 
                       +' '''', '''', ISNULL(OH.DeliveryPlace,''''), ISNULL(OH.DeliveryNote,''''), ISNULL(OH.B_Address1,''''), ISNULL(OH.B_Zip,''''), ' + CHAR(13)   --37
                       +' ISNULL(CL1.UDF01,''''), CASE WHEN @c_Sparm05 = ''1'' THEN OH.trackingno ELSE ISNULL(CT2.TrackingNo,'''') END, ISNULL(CL2.Long,''''), ' + CHAR(13)  --40   --CS01  
                       +' ISNULL(CL3.Long,''''), SUBSTRING(ISNULL(CL2.Notes,''''), 1, 80), SUBSTRING(ISNULL(CL2.[Description],''''), 1, 80), ISNULL(CL2.UDF01,''''), ISNULL(CL2.UDF02,''''), ' + CHAR(13)  --45   --WL01     
                       +' SUBSTRING(LTRIM(RTRIM(ISNULL(OH.C_State,''''))) + LTRIM(RTRIM(ISNULL(OH.C_City,''''))) + LTRIM(RTRIM(ISNULL(OH.C_Address1,''''))) + ' +   --WL01
                       +' LTRIM(RTRIM(ISNULL(OH.C_Address2,''''))) + LTRIM(RTRIM(ISNULL(OH.C_Address3,''''))) + LTRIM(RTRIM(ISNULL(OH.C_Address4,''''))), 1, 80), ' + CHAR(13)   --46   --WL01
                       +' ISNULL(OH.DeliveryNote,''''), '''', '''', '''', ' + CHAR(13)  --50   --WL01                           
                       +' '''', '''', '''', '''', '''', '''', '''', @c_Sparm01, @c_Sparm02, @c_Sparm05 ' + CHAR(13)  --60                
                       +' FROM ORDERS OH (NOLOCK) ' + CHAR(13)
                       +' JOIN FACILITY F (NOLOCK) ON OH.Facility = F.Facility ' + CHAR(13)
                       +' LEFT JOIN CODELKUP CL1 (NOLOCK) ON CL1.Listname = ''WSCourier'' AND CL1.Short = OH.ShipperKey ' + CHAR(13)
                       +'                                AND CL1.Storerkey = OH.StorerKey ' + CHAR(13)
                       +' LEFT JOIN CODELKUP CL2 (NOLOCK) ON CL2.Listname = ''NIKESoldTo'' AND CL2.Short = OH.B_Company ' + CHAR(13)
                       +' LEFT JOIN CODELKUP CL3 (NOLOCK) ON CL3.Listname = ''Expresstyp'' AND CL3.Code = OH.B_Zip ' + CHAR(13) 
                       +'                                AND CL3.Short = OH.Shipperkey ' + CHAR(13)
                       --+' LEFT JOIN CartonTrack CT1 (NOLOCK) ON CT1.LabelNo = OH.OrderKey AND CT1.KeyName = ''NIKE_IML'' AND CT1.CarrierRef1 = '''' ' + CHAR(13)
                       --+'                                   AND CT1.CarrierName = OH.ShipperKey ' + CHAR(13)
                       +' LEFT JOIN CartonTrack CT2 (NOLOCK) ON CT2.LabelNo = OH.OrderKey AND CT2.KeyName = ''NIKEO2SUB'' AND SUBSTRING(CT2.CarrierRef1, 11, 3) = @c_Sparm05 ' + CHAR(13)
                       +'                                   AND CT2.CarrierName = OH.ShipperKey ' + CHAR(13)  
                       +' WHERE OH.LoadKey = @c_Sparm01 '+ CHAR(13)              
                       +' AND OH.OrderKey = @c_Sparm02 '
   END

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
      
   SET @c_ExecArguments = N'  @c_Sparm01          NVARCHAR(80)'          
                         + ', @c_Sparm02          NVARCHAR(80) '      
                         + ', @c_Sparm03          NVARCHAR(80) ' 
                         + ', @c_Sparm04          NVARCHAR(80) ' 
                         + ', @c_Sparm05          NVARCHAR(80) '        
                                              
   EXEC sp_ExecuteSql     @c_SQL           
                        , @c_ExecArguments          
                        , @c_Sparm01         
                        , @c_Sparm02     
                        , @c_Sparm03   
                        , @c_Sparm04   
                        , @c_Sparm05   
                        
   IF @b_debug = 1              
   BEGIN                
      PRINT @c_SQL                
   END        
                 
   IF @b_debug = 1              
   BEGIN              
      SELECT * FROM #Result (nolock)              
   END    
   
   SELECT @n_SumQty = SUM(Pickdetail.Qty)
   FROM Pickdetail (NOLOCK)
   WHERE Pickdetail.OrderKey = @c_Sparm02   

   SELECT @n_SumWeight = SUM(PIF.[Weight]),@c_PIFTrackingno = MAX(PIF.Trackingno)  --ML01
   FROM PACKHEADER PH (NOLOCK)
   JOIN PACKINFO PIF (NOLOCK) ON PIF.PickSlipNo = PH.PickSlipNo AND PIF.CartonNo = @c_Sparm05
   WHERE PH.OrderKey = @c_Sparm02
   
   UPDATE #Result
   SET Col32 = @n_SumQty,
   	 Col33 = @n_SumWeight,
       Col39 = CASE WHEN @c_Shipperkey = 'SF' THEN @c_PIFTrackingno ELSE '' END  --ML01
   WHERE Col02 = @c_Sparm02
   
   SELECT * FROM #Result (nolock)            
                  
EXIT_SP:            
   SET @d_Trace_EndTime = GETDATE()        
   SET @c_UserName = SUSER_SNAME()        
                              
END -- procedure

GO