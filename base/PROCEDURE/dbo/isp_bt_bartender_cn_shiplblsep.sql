SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/******************************************************************************/                 
/* Copyright: IDS                                                             */                 
/* Purpose: isp_BT_Bartender_CN_SHIPLBLSEP                                    */                 
/*                                                                            */                 
/* Modifications log:                                                         */                 
/*                                                                            */                 
/* Date       Rev  Author     Purposes                                        */                 
/* 2020-05-13 1.0  CSCHONG    WMS-13268                                       */
/* 2020-12-15 1.1  WLChooi    WMS-15876 - Sync PROD version and add new Col15 */
/*                            (WL01)                                          */  
/******************************************************************************/                
                  
CREATE PROC [dbo].[isp_BT_Bartender_CN_SHIPLBLSEP]                      
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
      @n_TTLQty          INT      
          
    
  DECLARE @d_Trace_StartTime   DATETIME,   
          @d_Trace_EndTime     DATETIME,  
          @c_Trace_ModuleName  NVARCHAR(20),   
          @d_Trace_Step1       DATETIME,   
          @c_Trace_Step1       NVARCHAR(20),  
          @c_UserName          NVARCHAR(20),
          @c_ExecArguments     NVARCHAR(4000),
          @c_getloadkey        NVARCHAR(20),
          @c_orderkey          NVARCHAR(20),
          @c_Company           NVARCHAR(45),            
          @C_Address1          NVARCHAR(45),            
          @C_Address2          NVARCHAR(45),            
          @C_Address3          NVARCHAR(45),            
          @C_Address4          NVARCHAR(45), 
          @C_contact1          NVARCHAR(45),
          @C_Contact2          NVARCHAR(45),
          @C_City              NVARCHAR(45),
          @C_State             NVARCHAR(45),
          @c_Zip               NVARCHAR(18), 
          @C_Phone1            NVARCHAR(45),
          @C_Phone2            NVARCHAR(45),
          @C_Country           NVARCHAR(45),
          @c_c_Company         NVARCHAR(45),            
          @C_c_Address1        NVARCHAR(45),            
          @C_c_Address2        NVARCHAR(45),            
          @C_c_Address3        NVARCHAR(45),            
          @C_c_Address4        NVARCHAR(45), 
          @c_C_Contact1        NVARCHAR(45),
          @c_C_Contact2        NVARCHAR(45),
          @C_BuyerPO           NVARCHAR(20), 
          @c_C_City            NVARCHAR(45),
          @c_C_State           NVARCHAR(45),
          @c_C_Zip             NVARCHAR(18),  
          @c_C_Country         NVARCHAR(45),
          @c_C_Phone1          NVARCHAR(45),
          @c_C_Phone2          NVARCHAR(45),
          @b_success           INT          = 0,                                             
          @n_ErrNo             INT          = 0,                                             
          @c_ErrMsg            NVARCHAR(255)= '',
          @n_StartTCnt         INT,
          @n_Err               INT = 0 ,
          @n_Continue          INT             
  
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
               
    
   --CREATE NONCLUSTERED INDEX IDX_TMP_DECRYPTEDDATA ON #TMP_DECRYPTEDDATA (Orderkey)  
  
   SET @n_StartTCnt = @@TRANCOUNT  
  
   EXEC isp_Open_Key_Cert_Orders_PI  
      @n_Err    = @n_Err    OUTPUT,  
      @c_ErrMsg = @c_ErrMsg OUTPUT  
  
   IF ISNULL(@c_ErrMsg,'') <> ''  
   BEGIN  
      SET @n_Continue = 3  
      GOTO EXIT_SP  
   END  
  

            
  SET @c_SQLJOIN = +N' SELECT DISTINCT Right(pd.Labelno,10),f.contact1,f.address1,f.address2,o.c_company,'       --5
             + ' o.C_City,o.C_Address2,o.C_Address3,o.loadkey,CONVERT(nvarchar(10), GetDate(),126),' --10                
             + ' f.address3 ,Right(pd.Labelno,7),Right(pd.Labelno,17),'   --WL01
             + N' CASE WHEN datename(weekday,getdate()) = ''Monday'' Then N''星期一'' '
             + N'      WHEN datename(weekday,getdate()) = ''Tuesday'' Then N''星期二'' '   --WL01
             + N'      WHEN datename(weekday,getdate()) = ''Wednesday'' Then N''星期三'' '
             + N'      WHEN datename(weekday,getdate()) = ''Thursday'' Then N''星期四'' '
             + N'      WHEN datename(weekday,getdate()) = ''Friday'' Then N''星期五'' '
             + N'      WHEN datename(weekday,getdate()) = ''Saturday'' Then N''星期六'' '  
             + N'      WHEN datename(weekday,getdate()) = ''Sunday'' Then N''星期日'' ELSE '''' END,'
             + ' ISNULL(ST.SUSR1,''''), ' --15   --WL01                    --(CS02)
             + ' '''','''','''','''','''','     --20       
         --    + CHAR(13) +      
             + ' '''','''','''','''','''','''','''','''','''','''','  --30  
             + ' '''','''','''','''','''','''','''','''','''','''','   --40       
             + ' '''','''','''','''','''','''','''','''','''','''', '  --50       
             + ' '''','''','''','''','''','''','''','''','''','''' '   --60          
           --  + CHAR(13) +            
             + ' FROM PACKHEADER PH WITH (NOLOCK) ' 
             + ' JOIN PACKDETAIL PD WITH (NOLOCK) ON PD.PickSlipNo = PH.PickSlipNo'
             --+ ' JOIN ORDERS AS o WITH (NOLOCK) ON o.loadkey = ph.loadKey '          --WL01    
             + ' JOIN LoadPlanDetail LPD WITH (NOLOCK) ON LPD.Loadkey = ph.Loadkey '   --WL01
             + ' JOIN ORDERS AS o WITH (NOLOCK) ON o.Orderkey = LPD.Orderkey '         --WL01
             + ' JOIN FACILITY AS f WITH (NOLOCK) ON f.facility=o.facility '
             --+ ' JOIN PACKINFO AS PI WITH (NOLOCK) ON f.facility=o.facility '        --WL01
             + ' LEFT JOIN STORER ST WITH (NOLOCK) ON ST.Storerkey = O.Consigneekey AND ST.Type = ''2'' '   --WL01
             + ' WHERE pd.LabelNo = @c_Sparm02 '   
             + ' AND ph.Storerkey = @c_Sparm01 '   
            
          
IF @b_debug=1        
BEGIN        
   SELECT @c_SQLJOIN          
END                
              
  SET @c_SQL='INSERT INTO #Result (Col01,Col02,Col03,Col04,Col05, Col06,Col07,Col08,Col09'  + CHAR(13) +           
             +',Col10,Col11,Col12,Col13,Col14,Col15,Col16,Col17,Col18,Col19,Col20,Col21,Col22'  + CHAR(13) +           
             +',Col23,Col24,Col25,Col26,Col27,Col28,Col29,Col30,Col31,Col32,Col33,Col34' + CHAR(13) +           
             +',Col35,Col36,Col37,Col38,Col39,Col40,Col41,Col42,Col43,Col44'  + CHAR(13) +           
             +',Col45,Col46,Col47,Col48,Col49,Col50,Col51,Col52,Col53,Col54'+ CHAR(13) +           
             + ',Col55,Col56,Col57,Col58,Col59,Col60) '          
    
SET @c_SQL = @c_SQL + @c_SQLJOIN        
        
--EXEC sp_executesql @c_SQL          
   SET @c_ExecArguments = N'   @c_Sparm01           NVARCHAR(80)'    
                          + ', @c_Sparm02           NVARCHAR(80) '    
                          + ', @c_Sparm03           NVARCHAR(80)'                      
                         
   EXEC sp_ExecuteSql     @c_SQL     
                        , @c_ExecArguments    
                        , @c_Sparm01    
                        , @c_Sparm02   
                        , @c_Sparm03
        
   IF @b_debug=1        
   BEGIN          
      PRINT @c_SQL          
   END        
   IF @b_debug=1        
   BEGIN        
      SELECT * FROM #Result (nolock)        
   END                  
       
   
   SET @c_getloadkey =''
   SET @c_orderkey = ''

   SET @c_c_Company = ''
   SET @C_c_Address2 = ''
   SET @C_c_Address3 = ''
   SET @c_C_City = ''

   SELECT @c_getloadkey = Col09
   FROM #Result 

   SELECT @c_orderkey = MIN(O.Orderkey)
   FROM ORDERS O WITH (NOLOCK)
   WHERE O.loadkey = @c_getloadkey

    --EXEC [dbo].[isp_Create_Order_PI_Encrypted]  
    --              @c_OrderKey   =@c_OrderKey,
    --              @c_C_Contact1 =@c_C_Contact1,
    --              @c_C_Contact2 =@c_C_Contact2,
    --              @c_C_Company  =@C_Company,
    --              @c_C_Address1 =@C_C_Address1,
    --              @c_C_Address2 =@C_C_Address2,
    --              @c_C_Address3 =@C_C_Address3,
    --              @c_C_Address4 =@C_C_Address4,
    --              @c_C_City     =@C_C_City,
    --              @c_C_State    =@C_C_State,
    --              @c_C_Zip      =@C_C_Zip,
    --              @c_C_Country  =@C_C_Country,
    --              @c_C_Phone1   =@C_C_Phone1,
    --              @c_C_Phone2   =@C_C_Phone2,
    --              @b_success  = @b_success OUTPUT, 
    --              @n_ErrNo    = @n_ErrNo OUTPUT,
    --              @c_ErrMsg   = @c_ErrMsg OUTPUT   

     SELECT  @c_Company   = C_Company          
            ,@C_Address1  = C_Address1          
            ,@C_Address2  = C_Address2            
            ,@C_Address3  = C_Address3          
            ,@C_Address4  = C_Address4 
            ,@C_contact1  = C_Contact1
            ,@C_Contact2  = C_Contact2
            ,@C_City      = C_City
            ,@C_State     = C_State
            ,@c_zip       = C_Zip
            ,@C_Phone1    = C_Phone1
            ,@C_Phone2    = C_Phone2 
          --  ,@C_Country   = C_Country  
      FROM fnc_GetDecryptedOrderPI (@c_orderkey)    
    --FROM Orders_PI_Encrypted WITH (NOLOCK)
    --WHERE Orderkey = @c_OrderKey  
    
    UPDATE #Result          
   SET Col05 = @c_Company,
       Col07 = @C_Address2,
       Col08 = @C_Address3,
       Col06 = @C_City
   WHERE Col09=@c_getloadkey       
            
   EXIT_SP:    
  
   SET @d_Trace_EndTime = GETDATE()  
   SET @c_UserName = SUSER_SNAME()  
     
   EXEC isp_InsertTraceInfo   
      @c_TraceCode = 'BARTENDER',  
      @c_TraceName = 'isp_BT_Bartender_CN_SHIPLBLSEP',  
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