SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/******************************************************************************/                   
/* Copyright: IDS                                                             */                   
/* Purpose: isp_BT_Bartender_CN_SHPLBVIPUA                                    */                   
/*                                                                            */                   
/* Modifications log:                                                         */                   
/*                                                                            */                   
/* Date       Rev  Author     Purposes                                        */  
/* 2022-08-10 1.0  CSCHONG    DevOps Scripts Combine & Created(WMS-20331)     */
/******************************************************************************/                  
                    
CREATE PROC [dbo].[isp_BT_Bartender_CN_SHPLBVIPUA]                        
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
      @c_ReceiptKey      NVARCHAR(10),                      
      @c_sku             NVARCHAR(20),                           
      @n_intFlag         INT,       
      @n_CntRec          INT,      
      @c_SQL             NVARCHAR(4000),          
      @c_SQLSORT         NVARCHAR(4000),          
      @c_SQLJOIN         NVARCHAR(4000),  
      @c_col58           NVARCHAR(10),
      @c_labelline       NVARCHAR(10),
      @n_CartonNo        INT        
      
   DECLARE @d_Trace_StartTime  DATETIME,     
           @d_Trace_EndTime    DATETIME,    
           @c_Trace_ModuleName NVARCHAR(20),     
           @d_Trace_Step1      DATETIME,     
           @c_Trace_Step1      NVARCHAR(20),    
           @c_UserName         NVARCHAR(20),      
           @c_SKU01            NVARCHAR(80),           
           @c_SKU02            NVARCHAR(80),    
           @c_SKU03            NVARCHAR(80),           
           @c_SKU04            NVARCHAR(80),   
           @c_SKU05            NVARCHAR(80),           
           @c_SKU06            NVARCHAR(80),  
           @c_SIZE01           NVARCHAR(10), 
           @c_SIZE02           NVARCHAR(10), 
           @c_SIZE03           NVARCHAR(10), 
           @c_SIZE04           NVARCHAR(10), 
           @c_SIZE05           NVARCHAR(10), 
           @c_SIZE06           NVARCHAR(10), 
           @c_Color01          NVARCHAR(10),    
           @c_Color02          NVARCHAR(10), 
           @c_Color03          NVARCHAR(10), 
           @c_Color04          NVARCHAR(10), 
           @c_Color05          NVARCHAR(10), 
           @c_Color06          NVARCHAR(10),                       
           @c_SKUQty01         NVARCHAR(10),          
           @c_SKUQty02         NVARCHAR(10),    
           @c_SKUQty03         NVARCHAR(10),          
           @c_SKUQty04         NVARCHAR(10),     
           @c_SKUQty05         NVARCHAR(10),          
           @c_SKUQty06         NVARCHAR(10),                     
           @n_TTLpage          INT,          
           @n_CurrentPage      INT,  
           @n_MaxLine          INT  ,  
           @c_labelno          NVARCHAR(20) ,  
           @c_orderkey         NVARCHAR(20) ,  
           @n_skuqty           INT ,  
           @n_skurqty          INT ,  
           @c_cartonno         NVARCHAR(5),  
           @n_loopno           INT,  
           @c_LastRec          NVARCHAR(1),  
           @c_ExecStatements   NVARCHAR(4000),      
           @c_ExecArguments    NVARCHAR(4000),   
           
           @c_MaxLBLLine       INT,
           @c_SumQTY           INT,
           @n_MaxCarton        INT,
           @c_SDESCR           NVARCHAR(80),
           @c_SSize            NVARCHAR(10),
           @c_Style            NVARCHAR(20),
           @c_color            NVARCHAR(10),
           @n_SumPack          INT,
           @n_SumPick          INT,
           @n_MaxCtnNo         INT,
           @c_storerkey        NVARCHAR(20),
           @c_OrdLineNo        NVARCHAR(10),
           @c_altsku           NVARCHAR(20),
           @c_col43            NVARCHAR(80),   
           @c_col44            NVARCHAR(80),    
           @c_col45            NVARCHAR(80),  
           @c_col46            NVARCHAR(80),  
           @c_col47            NVARCHAR(80),  
           @c_col48            NVARCHAR(80)
             

    --SELECT @n_MaxCarton = MAX(PD.CartonNo)
    --FROM PACKDETAIL PD (NOLOCK)
    --WHERE PD.PICKSLIPNO = @c_Sparm01

    SELECT @n_SumPick = SUM(Qty)
    FROM PICKDETAIL (NOLOCK)
    WHERE Orderkey = @c_Sparm01
    AND Status IN ('5','9')
    
    SET @d_Trace_StartTime = GETDATE()    
    SET @c_Trace_ModuleName = ''    
          
    -- SET RowNo = 0               
    SET @c_SQL = ''       
    SET @n_CurrentPage = 1  
    SET @n_TTLpage =1       
    SET @n_MaxLine = 6    
    SET @n_CntRec = 1    
    SET @n_intFlag = 1   
    SET @n_loopno = 1        
    SET @c_LastRec = 'Y'  
                
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
      
         
       SET @c_SQLJOIN = +' SELECT DISTINCT ISNULL(C.UDF01,''''), ISNULL(F.Address1,''''), ISNULL(F.Address2,''''), ISNULL(F.Address3,''''), ISNULL(F.Address4,''''), '   + CHAR(13) --5
                        +' ISNULL(F.Userdefine11,''''), ISNULL(F.City,''''), '+ CHAR(13) --7
                        +' ISNULL(F.contact1,''''), '+ CHAR(13) --8
                        +' ISNULL(F.phone1,''''), ISNULL(F.phone2,''''), '+ CHAR(13)      --10        
                        +' ISNULL(F.State,''''), ISNULL(F.Zip,''''), ORD.Consigneekey, ORD.C_Company, ORD.Ordergroup, '+ CHAR(13) --15
                        +' ISNULL(ORD.C_Address1,''''), ISNULL(ORD.C_Address2,''''), ISNULL(ORD.C_Address3,''''), ISNULL(ORD.C_Address4,''''), ISNULL(ORD.C_City,''''), '+ CHAR(13)  --20
                        +' ISNULL(ORD.C_Contact1,''''),ISNULL(ORD.C_Phone1,''''),ISNULL(ORD.C_Phone2,''''),ISNULL(ORD.C_State,''''),ISNULL(ORD.C_Zip,''''),'  --25
                        +' ORD.CurrencyCode,ORD.deliveryPlace,ORD.ExternOrderkey,ORD.Facility,ORD.M_Company, ' + CHAR(13) --30 
                        +' SUBSTRING(ISNULL(ORD.notes2,''''),1,80),CONVERT(NVARCHAR(10),ORD.OrderDate,120),ORD.Orderkey,ORD.shipperkey,ORD.Storerkey,'  --35
                        +' ORD.Trackingno,ORD.Type,ISNULL(ORD.Userdefine04,''''),LEFT(ORD.Userdefine05 ,CHARINDEX(''|'' ,ORD.Userdefine05 + ''|'') -1) , '
                        +' RIGHT(ORD.Userdefine05 ,CHARINDEX(''|'' ,ORD.Userdefine05 + ''|'') -1) , ' + CHAR(13) --40 
                        +' CONVERT(NVARCHAR(10),GETDATE(),120),CONVERT(NVARCHAR(8),GETDATE(),114),'''','''','''','
                        +' '''','''','''',ISNULL(CT.UDF02,''''),ISNULL(CT.UDF03,''''), ' + CHAR(13) --50 
                        +' ISNULL(CT.UDF01,''''),SUBSTRING(ISNULL(CT.printdata,''''),1,80),SUBSTRING(ISNULL(CT.printdata,''''),81,80),@n_SumPick,'''', ' + CHAR(13) --55
                        +' '''','''','''','''', '''' ' + CHAR(13) --60                                           
                        +' FROM ORDERS ORD WITH (NOLOCK)    '+ CHAR(13)       
                       -- +' JOIN ORDERDETAIL OD WITH (NOLOCK) ON ORD.Orderkey = OD.Orderkey '+ CHAR(13)      
                        --+' JOIN PICKDETAIL PD WITH (NOLOCK) ON PD.OrderKey = OD.OrderKey ' 
                        --+' AND PD.OrderLineNumber = OD.OrderLineNumber AND PD.sku = OD.sku '+ CHAR(13)  
                        +' JOIN FACILITY F WITH (NOLOCK) ON F.FACILITY = ORD.FACILITY ' + CHAR(13)    
                        +' JOIN CARTONTRACK CT WITH (NOLOCK) ON ORD.Orderkey = CT.labelno AND CT.trackingno=ORD.Trackingno'+ CHAR(13)      
                        +' LEFT JOIN CODELKUP C WITH (NOLOCK) ON  C.listname=''VIPCARRCOD'' and C.short = ORD.shipperkey AND C.long = ORD.ordergroup AND C.code2=ORD.facility' + CHAR(13)                    
                        +' WHERE ORD.Orderkey = @c_Sparm01       '

       
  IF @b_debug=1          
  BEGIN          
   PRINT @c_SQLJOIN            
  END                  
                
  SET @c_SQL='INSERT INTO #Result (Col01,Col02,Col03,Col04,Col05, Col06,Col07,Col08,Col09'  + CHAR(13) +             
             +',Col10,Col11,Col12,Col13,Col14,Col15,Col16,Col17,Col18,Col19,Col20,Col21,Col22'  + CHAR(13) +             
             +',Col23,Col24,Col25,Col26,Col27,Col28,Col29,Col30,Col31,Col32,Col33,Col34' + CHAR(13) +             
             +',Col35,Col36,Col37,Col38,Col39,Col40,Col41,Col42,Col43,Col44'  + CHAR(13) +             
             +',Col45,Col46,Col47,Col48,Col49,Col50,Col51,Col52,Col53,Col54'+ CHAR(13) +             
             + ',Col55,Col56,Col57,Col58,Col59,Col60) '            
      
SET @c_SQL = @c_SQL + @c_SQLJOIN      
  
  
 SET @c_ExecArguments = N'     @c_Sparm01          NVARCHAR(80)'
                      +  ',    @n_SumPick          INT'        
                           
                           
   EXEC sp_ExecuteSql     @c_SQL       
                        , @c_ExecArguments      
                        , @c_Sparm01     
                        , @n_SumPick 
     
          
    --EXEC sp_executesql @c_SQL            
          
   IF @b_debug=1          
   BEGIN            
      PRINT @c_SQL            
   END    
     
           
   IF @b_debug=1          
   BEGIN          
      SELECT * FROM #Result (nolock)          
   END      


   DECLARE CUR_RowNoLoop CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
   SELECT DISTINCT PID.OrderKey, PID.OrderLineNumber,Sku.color,sku.size,PID.sku,Sku.altsku
                    , PID.Qty
      FROM ORDERS ORD (NOLOCK) 
      JOIN ORDERDETAIL OD (NOLOCK) ON ORD.ORDERKEY = OD.ORDERKEY
      JOIN PICKDETAIL PID (NOLOCK) ON PID.ORDERKEY = ORD.ORDERKEY AND PID.ORDERLINENUMBER = OD.ORDERLINENUMBER
                                  AND PID.SKU = OD.SKU
      --JOIN LOTATTRIBUTE LOTT (NOLOCK) ON LOTT.LOT = PID.LOT
      JOIN SKU (NOLOCK) ON PID.SKU = SKU.SKU AND PID.STORERKEY = SKU.STORERKEY
      WHERE PID.OrderKey = @c_Sparm01
      AND  PID.Status IN ('5','9')
      GROUP BY PID.OrderKey, PID.OrderLineNumber,Sku.color,sku.size,PID.sku,Sku.altsku
                    , PID.Qty
      ORDER BY PID.OrderKey, PID.OrderLineNumber
                       
            
   OPEN CUR_RowNoLoop                    
               
   FETCH NEXT FROM CUR_RowNoLoop INTO @c_orderkey,@c_OrdLineNo,@c_color,@c_SSize,@c_sku,@c_altsku,@n_skuqty      
                 
   WHILE @@FETCH_STATUS <> -1               
   BEGIN                   
      IF @b_debug='1'                
      BEGIN                
         PRINT @c_OrdLineNo                   
      END   
      
    
      SET @c_SIZE01 = ''  
      SET @c_SIZE02 = ''
      SET @c_SIZE03 = ''
      SET @c_SIZE04 = ''
      SET @c_SIZE05 = ''
      SET @c_SIZE06 = ''


      SET @c_Color01 = ''  
      SET @c_Color02 = ''
      SET @c_Color03 = ''
      SET @c_Color04 = ''
      SET @c_Color05 = ''
      SET @c_Color06 = ''

      
      SET @c_SKU01 = ''  
      SET @c_SKU02 = ''  
      SET @c_SKU03 = ''  
      SET @c_SKU04 = ''  
      SET @c_SKU05 = ''  
      SET @c_SKU06 = ''  

      
      SET @c_SKUQty01 = ''  
      SET @c_SKUQty02 = ''  
      SET @c_SKUQty03 = ''  
      SET @c_SKUQty04 = ''  
      SET @c_SKUQty05 = ''  
      SET @c_SKUQty06 = ''  
      

      SET @c_col43 = ''
      SET @c_col44 = ''
      SET @c_col45 = ''
      SET @c_col46 = ''
      SET @c_col47 = ''
      SET @c_col48 = ''

      IF @c_OrdLineNo ='00001'
      BEGIN
       SET @c_Size01  = @c_SSize
       SET @c_Color01 = @c_color    
       SET @c_sku01 = @c_altsku  
       SET @c_SKUQty01 = CONVERT(NVARCHAR(10),@n_skuqty)     

      SET @c_col43 = @c_sku01 +'*'+ @c_Color01 +'*'+ @c_Size01 +'*'+  @c_SKUQty01 

      END

      IF @c_OrdLineNo ='00002'
      BEGIN      
       SET @c_Size02  = @c_SSize
       SET @c_Color02 = @c_color 
       SET @c_sku02 = @c_altsku  
       SET @c_SKUQty02= CONVERT(NVARCHAR(10),@n_skuqty)     

      SET @c_col44 = @c_sku02 +'*'+ @c_Color02 +'*'+ @c_Size02 +'*'+  @c_SKUQty02          
      END   

      IF @c_OrdLineNo ='00003'
      BEGIN      
       SET @c_Size03  = @c_SSize
       SET @c_Color03 = @c_color  
       SET @c_sku03 = @c_altsku  
       SET @c_SKUQty03 = CONVERT(NVARCHAR(10),@n_skuqty)      

      SET @c_col45 = @c_sku03 +'*'+ @c_Color03 +'*'+ @c_Size03 +'*'+  @c_SKUQty03       
      END 

      IF @c_OrdLineNo ='00004'
      BEGIN      
       SET @c_Size04  = @c_SSize
       SET @c_Color04 = @c_color    
       SET @c_sku04 =@c_altsku  
       SET @c_SKUQty04 = CONVERT(NVARCHAR(10),@n_skuqty)     

      SET @c_col46 = @c_sku04 +'*'+ @c_Color04 +'*'+ @c_Size04 +'*'+  @c_SKUQty04
      END 

      IF @c_OrdLineNo ='00005'
      BEGIN      

       SET @c_Size05  = @c_SSize
       SET @c_Color05 = @c_color    
       SET @c_sku05 = @c_altsku  
       SET @c_SKUQty05 = CONVERT(NVARCHAR(10),@n_skuqty)   

      SET @c_col47 = @c_sku05 +'*'+ @c_Color05 +'*'+ @c_Size05 +'*'+  @c_SKUQty05      
      END 

      IF @c_OrdLineNo ='00006' 
      BEGIN      
       SET @c_Size06  = @c_SSize
       SET @c_Color06 = @c_color  
       SET @c_sku06 = @c_altsku  
       SET @c_SKUQty06= CONVERT(NVARCHAR(10),@n_skuqty)     

      SET @c_col48 = @c_sku06 +'*'+ @c_Color06 +'*'+ @c_Size06 +'*'+  @c_SKUQty06      
      END 


  UPDATE #Result                    
  SET Col43 = @c_col43,
      Col44 = @c_col44,
      Col45 = @c_col45,
      Col46 = @c_col46,
      Col47 = @c_col47,
      Col48 = @c_col48
    WHERE col33 =  @c_orderkey     
   
   FETCH NEXT FROM CUR_RowNoLoop INTO @c_orderkey,@c_OrdLineNo,@c_color,@c_SSize,@c_sku,@c_altsku,@n_skuqty        
          
   END -- While                     
   CLOSE CUR_RowNoLoop                    
   DEALLOCATE CUR_RowNoLoop
   
   SELECT * FROM #Result    

              
EXIT_SP:      
    
   SET @d_Trace_EndTime = GETDATE()    
   SET @c_UserName = SUSER_SNAME()    
       
   --EXEC isp_InsertTraceInfo     
   --   @c_TraceCode = 'BARTENDER',    
   --   @c_TraceName = 'isp_BT_Bartender_CN_SHPLBVIPUA',    
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