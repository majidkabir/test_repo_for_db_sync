SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/******************************************************************************/                 
/* Copyright: IDS                                                             */                 
/* Purpose: isp_Bartender_Shipper_Label_KR_Hanjin                             */                 
/*                                                                            */                 
/* Modifications log:                                                         */                 
/*                                                                            */                 
/* Date       Rev  Author     Purposes                                        */                 
/* 2015-10-06 1.0  CSCHONG    Created (WMS-2053)                              */ 
/* 2018-04-20 1.2  CSCHONG    SET ANSI_WARNINGS OFF (CS01)                    */   
/* 2019-02-20 1.3  CSCHONG    WMS-8029 revised field logic (CS02)             */
/* 2020-09-23 1.4  WLChooi    WMS-14956 - Add new column (WL01)               */     
/* 2020-10-14 1.5  WLChooi    Show Qty Per Carton (WL02)                      */        
/* 2021-01-04 1.6  CSCHONG    Devops Scripts Combine and WMS-18668 (CS03)     */
/******************************************************************************/                
                  
CREATE PROC [dbo].[isp_Bartender_Shipper_Label_KR_Hanjin]                      
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
 --  SET ANSI_WARNINGS OFF                        --(CS01)      
 
   DECLARE @d_Trace_StartTime   DATETIME,   
           @d_Trace_EndTime    DATETIME,  
           @c_Trace_ModuleName NVARCHAR(20),   
           @d_Trace_Step1      DATETIME,   
           @c_Trace_Step1      NVARCHAR(20),  
           @c_UserName         NVARCHAR(20),
           @c_SQL             NVARCHAR(MAX),   --WL01      
           @c_SQLJOIN         NVARCHAR(MAX)    --WL01     
           
   DECLARE @c_ExecStatements       NVARCHAR(MAX)  
         , @c_ExecArguments        NVARCHAR(MAX)  
         , @c_ExecStatements2      NVARCHAR(MAX)  
         , @c_ExecStatementsAll    NVARCHAR(MAX)    
         , @n_continue             INT         
         , @c_Col33                NVARCHAR(80)   --WL01  
         , @c_Col41                NVARCHAR(80)   --WL01  
         , @c_Col42                NVARCHAR(80)   --WL01  
  
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
              
   IF @b_debug=1        
   BEGIN        
      PRINT 'start'          
   END        

   SET @c_SQLJOIN = +' SELECT CSC.SortingCode2,CSC.SortingCode1,LEFT(CSC.SortingCode3,2),RIGHT(CSC.SortingCode3,2),CSC.Comment,'+ CHAR(13) +     --5    
             + ' CSC.[State],CSC.City,CSC.Province,CONVERT(CHAR(10), getDate(), 120),OH.C_Company,'      --10
             + ' OH.C_Phone1,SUBSTRING(OH.C_CITY + OH.C_State + LTRIM(OH.C_Address1) + LTRIM(OH.C_Address2) + LTRIM(OH.C_Address3) + LTRIM(OH.C_Address4),1,80),'
             + ' OH.C_Zip,ST.B_Company,ST.B_Phone1,SUBSTRING(ST.B_Address1+ST.B_Address2,1,80),OH.Notes,OH.Externorderkey,OH.OrderKey,SUM(PID.QTY),'             --20
             + '(Substring(PD.LabelNo,1,4) + ''-'' + Substring(PD.LabelNo,5,4) +''-'' +Substring(PD.LabelNo,9,4)), '
             + ' (Substring(PD.LabelNo,1,4) + Substring(PD.LabelNo,5,4) + Substring(PD.LabelNo,9,4)),'                       --22  
             + CHAR(13) +         
             + ' ST.B_contact1,ST.B_City,ST.B_State,ST.Notes2,PD.CartonNo,MAX(PD.CartonNo),' --28   --CS02
             + ' Substring(PD.labelno,1,4) + ''-'' + Substring(PD.labelno,5,4)  + ''-'' +  Substring(PD.labelno,9,4), PD.LabelNo,'  --30   --WL01 
             + ' SUBSTRING(OH.C_Phone1,1,LEN(OH.C_Phone1) - LEN(RIGHT(OH.C_Phone1, 4))) + ''****'', '   --31   --WL01
             + ' SUBSTRING(OH.C_Phone2,1,LEN(OH.C_Phone2) - LEN(RIGHT(OH.C_Phone2, 4))) + ''****'','   --32   --WL01
             + ' SUBSTRING((LTRIM(RTRIM(ISNULL(OH.C_Address1,''''))) + LTRIM(RTRIM(ISNULL(OH.C_Address2,''''))) + 
                 LTRIM(RTRIM(ISNULL(OH.C_Address3,''''))) + LTRIM(RTRIM(ISNULL(OH.C_Address4,'''')))), 1, 80),'   --33   --WL01
             + ' ISNULL(CSC1.Province,''''),OH.DeliveryNote,SUBSTRING(ISNULL(CL1.Notes,''''),1,80),SUBSTRING(ISNULL(CL1.Notes2,''''),1,80), '   --WL01
             + ' ISNULL(OIF.EcomOrderID,''''), '   --WL01
             + ' CASE WHEN ISNULL(CL1.Notes,'''') <> '''' THEN SUBSTRING(CL1.Notes,1,LEN(CL1.Notes) - LEN(RIGHT(CL1.Notes, 4))) + ''****'' ELSE '''' END, '   --WL01
             + ' OH.C_Contact1, ' + CHAR(13) +     --40   --WL01       
             + ' '''',(SELECT SUM(PAD.Qty) 
                       FROM PACKDETAIL PAD (NOLOCK) 
                       JOIN PACKHEADER PAH (NOLOCK) ON PAH.Pickslipno = PAD.Pickslipno
                       WHERE PAH.Orderkey = @c_Sparm01 AND PAD.CartonNo = PD.CartonNo), '   --WL02
             + ' '''','''','''','''','''','''','''','''', ' + CHAR(13) +    --50            --WL02       
             + ' '''','''','''','''','''','''','''','''','''', '''' '   --60          
             + CHAR(13) +            
             + ' FROM ORDERS OH WITH (NOLOCK)' + CHAR(13) +        
             + ' JOIN PACKHEADER PH WITH (NOLOCK) ON PH.OrderKey= OH.OrderKey' + CHAR(13) +   
             + ' JOIN PACKDETAIL PD WITH (NOLOCK) ON PH.Pickslipno = PD.Pickslipno' + CHAR(13) +  
             + ' LEFT JOIN PICKDETAIL PID WITH (NOLOCK) ON PID.CaseID = PD.LabelNo ' + CHAR(13) +  
             + ' LEFT JOIN CourierSortingCode CSC WITH (NOLOCK) ON CSC.Zip=OH.C_Zip AND isnull(CSC.shipperkey,'''') = '''' ' + CHAR(13) +    --CS03
             + ' LEFT JOIN CODELKUP CL WITH (NOLOCK) ON CL.Listname = ''HJCOURIER'' AND CL.Storerkey = OH.Storerkey ' + CHAR(13) +     --WL01
             + ' LEFT JOIN CourierSortingCode CSC1 WITH (NOLOCK) ON CSC1.State = CL.Short AND CSC1.City = CSC.SortingCode1      
                                                                AND CSC1.Shipperkey = ''HANJIN'' AND CSC1.Comment = ''HUB'' ' + CHAR(13) +     --WL01
             + ' LEFT JOIN CODELKUP CL1 WITH (NOLOCK) ON CL1.Listname = ''ADBrand'' AND CL1.Code = OH.DeliveryPlace
                                                     AND CL1.Storerkey = OH.Storerkey ' + CHAR(13) +     --WL01
             + ' JOIN STORER ST WITH (NOLOCK) ON OH.Storerkey=ST.Storerkey' + CHAR(13) +  
             + ' LEFT JOIN ORDERINFO OIF WITH (NOLOCK) ON OIF.Orderkey = OH.Orderkey ' + CHAR(13) +    --WL01
             + ' WHERE PH.OrderKey = @c_Sparm01 ' + CHAR(13) +     
             + ' AND PD.Cartonno = CASE WHEN ISNULL(RTRIM(@c_Sparm02),'''')<> '''' THEN @c_Sparm02 ELSE PD.Cartonno END' + CHAR(13) +   
             + ' GROUP BY CSC.SortingCode2,CSC.SortingCode1,LEFT(CSC.SortingCode3,2),RIGHT(CSC.SortingCode3,2),CSC.Comment, CSC.[State],CSC.City,CSC.Province, ' + CHAR(13) +  
             + ' OH.C_Company,  OH.C_Phone1,OH.C_CITY , OH.C_State ,LTRIM(OH.C_Address1), LTRIM(OH.C_Address2) , LTRIM(OH.C_Address3) , LTRIM(OH.C_Address4),' + CHAR(13) +  
             + ' OH.C_Zip, ST.B_Company,ST.B_Phone1, ' + CHAR(13) +  
             + ' ST.B_Address1+ST.B_Address2,OH.Notes,OH.Externorderkey,OH.OrderKey,PD.LabelNo, ST.B_contact1,ST.B_City,ST.B_State,ST.Notes2,PD.CartonNo, ' + CHAR(13) +       --CS02
             + ' SUBSTRING(OH.C_Phone1,1,LEN(OH.C_Phone1) - LEN(RIGHT(OH.C_Phone1, 4))) + ''****'', ' + CHAR(13) +     --WL01
             + ' SUBSTRING(OH.C_Phone2,1,LEN(OH.C_Phone2) - LEN(RIGHT(OH.C_Phone2, 4))) + ''****'', ' + CHAR(13) +     --WL01
             + ' SUBSTRING((LTRIM(RTRIM(ISNULL(OH.C_Address1,''''))) + LTRIM(RTRIM(ISNULL(OH.C_Address2,''''))) + ' + CHAR(13) +  
             + ' LTRIM(RTRIM(ISNULL(OH.C_Address3,''''))) + LTRIM(RTRIM(ISNULL(OH.C_Address4,'''')))), 1, 80), ' + CHAR(13) +     --WL01
             + ' ISNULL(CSC1.Province,''''), OH.DeliveryNote,SUBSTRING(ISNULL(CL1.Notes,''''),1,80),SUBSTRING(ISNULL(CL1.Notes2,''''),1,80), ' + CHAR(13) +     --WL01
             + ' ISNULL(OIF.EcomOrderID,''''), ' + CHAR(13) +     --WL01
             + ' CASE WHEN ISNULL(CL1.Notes,'''') <> '''' THEN SUBSTRING(CL1.Notes,1,LEN(CL1.Notes) - LEN(RIGHT(CL1.Notes, 4))) + ''****'' ELSE '''' END, '   --WL01
             + ' OH.C_Contact1 '   --WL01
                       
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
    
   --SET @c_SQL = @c_SQL + @c_SQLJOIN  
  
   --SET @c_SQL = @c_SQL + @c_SQLJOIN   
   SET @c_ExecStatements = @c_SQL + CHAR(13) + @c_SQLJOIN 
       
   IF @b_debug=1        
   BEGIN        
      SELECT @c_ExecStatements          
   END  
       
   SET @c_ExecArguments = N' @c_Sparm01    NVARCHAR(60)'  
                          +',@c_Sparm02    NVARCHAR(60)'  
                                     
  
   EXEC sp_ExecuteSql @c_ExecStatements   
                    , @c_ExecArguments  
                    , @c_Sparm01  
                    , @c_Sparm02  
  
   IF @@ERROR <> 0       
   BEGIN  
      SET @n_continue = 3  
      ROLLBACK TRAN  
      GOTO EXIT_SP  
   END       
     
   --EXEC sp_executesql @c_SQL          
        
   IF @b_debug=1        
   BEGIN          
      PRINT @c_SQL          
   END  
   
   --WL01 START
   SELECT @c_Col33 = Col33
   FROM #Result r
   
   SELECT @c_Col41 = CASE WHEN ISNULL(@c_Col33,'') <> '' AND LEN(@c_Col33) > 11
                          THEN REPLACE(@c_Col33,SUBSTRING(@c_Col33,11,LEN(@c_Col33)),'*')
                          ELSE '' END
                          
   SELECT @c_Col42 = SUM(PACKDETAIL.Qty)
   FROM PACKHEADER (NOLOCK)
   JOIN PACKDETAIL (NOLOCK) ON PACKHEADER.PickSlipNo = PACKDETAIL.PickSlipNo
   WHERE PACKHEADER.OrderKey = @c_Sparm01
                     
   UPDATE #Result
   SET Col41 = @c_Col41--,
       --Col42 = @c_Col42   --WL02
   --WL01 END

   IF @b_debug=1        
   BEGIN        
      SELECT * FROM #Result (nolock)        
   END        
      
   SELECT * FROM #Result (nolock)        
            
EXIT_SP:    
  
   SET @d_Trace_EndTime = GETDATE()  
   SET @c_UserName = SUSER_SNAME()  
     
      --EXEC isp_InsertTraceInfo   
      --   @c_TraceCode = 'BARTENDER',  
      --   @c_TraceName = 'isp_Bartender_Shipper_Label_KR_Hanjin',  
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