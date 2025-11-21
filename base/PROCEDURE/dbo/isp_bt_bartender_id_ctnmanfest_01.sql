SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/******************************************************************************/                   
/* Copyright: IDS                                                             */                   
/* Purpose: isp_BT_Bartender_ID_CTNMANFEST_01                                 */                   
/*                                                                            */                   
/* Modifications log:                                                         */                   
/*                                                                            */                   
/* Date       Rev  Author     Purposes                                        */   
/* 2023-04-18 1.0  CSCHONG    Devops Scripts Combine & Created (WMS-21802)    */   
/* 2023-06-22 1.1  CSCHONG    WMS-21802 Fix ttlpage issue (CS01)              */       
/* 2023-08-21 1.2  CSCHONG    WMS-23388 revised field mapping (CS02)          */      
/******************************************************************************/                  
                    
CREATE   PROC [dbo].[isp_BT_Bartender_ID_CTNMANFEST_01]                        
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
      @c_OrderKey        NVARCHAR(10),  
      @c_dropid          NVARCHAR(20),                    
      @c_sku             NVARCHAR(20),                           
      @n_intFlag         INT,       
      @n_CntRec          INT,      
      @n_labelline       INT,   
      @c_SQL             NVARCHAR(4000),          
      @c_SQLSORT         NVARCHAR(4000),          
      @c_SQLJOIN         NVARCHAR(4000),  
      @c_SStyle          NVARCHAR(20),  
      @c_SSize           NVARCHAR(20),  
      @c_Sdescr          NVARCHAR(60),  
      @c_barcode         NVARCHAR(80), 
      @c_ExecStatements  NVARCHAR(4000),        
      @c_ExecArguments   NVARCHAR(4000),
      @c_externorderkey  NVARCHAR(50)             
      
  DECLARE @d_Trace_StartTime   DATETIME,     
           @d_Trace_EndTime    DATETIME,    
           @c_Trace_ModuleName NVARCHAR(20),     
           @d_Trace_Step1      DATETIME,     
           @c_Trace_Step1      NVARCHAR(20),    
           @c_UserName         NVARCHAR(20),  
           @c_SDESCR01         NVARCHAR(60),           
           @c_SDESCR02         NVARCHAR(60),            
           @c_SDESCR03         NVARCHAR(60),          
           @c_SDESCR04         NVARCHAR(60),          
           @c_SDESCR05         NVARCHAR(60),    
           @c_SDESCR06         NVARCHAR(60),      
           @c_SDESCR07         NVARCHAR(60),     
           @c_SDESCR08         NVARCHAR(60),      
           @c_SSTYLE01         NVARCHAR(20),           
           @c_SSTYLE02         NVARCHAR(20),            
           @c_SSTYLE03         NVARCHAR(20),          
           @c_SSTYLE04         NVARCHAR(20),          
           @c_SSTYLE05         NVARCHAR(20),    
           @c_SSTYLE06         NVARCHAR(20),   
           @c_SSTYLE07         NVARCHAR(20),   
           @c_SSTYLE08         NVARCHAR(20),      
           @c_SSIZE01          NVARCHAR(20),           
           @c_SSIZE02          NVARCHAR(20),            
           @c_SSIZE03          NVARCHAR(20),          
           @c_SSIZE04          NVARCHAR(20),          
           @c_SSIZE05          NVARCHAR(20),  
           @c_SSIZE06          NVARCHAR(20),  
           @c_SSIZE07          NVARCHAR(20),  
           @c_SSIZE08          NVARCHAR(20),       
           @n_Labelno01        INT,           
           @n_Labelno02        INT,             
           @n_Labelno03        INT,         
           @n_Labelno04        INT,         
           @n_Labelno05        INT,      
           @n_Labelno06        INT,            
           @n_Labelno07        INT,           
           @c_SColor08         NVARCHAR(20),                  
           @c_SKUQty01         NVARCHAR(10),          
           @c_SKUQty02         NVARCHAR(10),           
           @c_SKUQty03         NVARCHAR(10),           
           @c_SKUQty04         NVARCHAR(10),           
           @c_SKUQty05         NVARCHAR(10) ,  
           @c_SKUQty06         NVARCHAR(10) ,  
           @c_SKUQty07         NVARCHAR(10) ,  
           @c_SKUQty08         NVARCHAR(10) ,  
           @c_Barcode01        NVARCHAR(80),           
           @c_Barcode02        NVARCHAR(80),            
           @c_Barcode03        NVARCHAR(80),          
           @c_Barcode04        NVARCHAR(80),          
           @c_Barcode05        NVARCHAR(80),    
           @c_Barcode06        NVARCHAR(80),      
           @c_Barcode07        NVARCHAR(80),     
           @c_Barcode08        NVARCHAR(80), 
           @n_TTLpage          INT,          
           @n_CurrentPage      INT,  
           @n_MaxLine          INT  ,  
           @c_ToId             NVARCHAR(80) ,  
           @c_RDRECkey         NVARCHAR(20) ,  
           @n_skuqty           INT   
    
   SET @d_Trace_StartTime = GETDATE()    
   SET @c_Trace_ModuleName = ''    
          
    -- SET RowNo = 0               
    SET @c_SQL = ''       
    SET @n_CurrentPage = 1  
    SET @n_TTLpage =1       
    SET @n_MaxLine = 7    
    SET @n_CntRec = 1    
    SET @n_intFlag = 1          
                
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
       
       
      CREATE TABLE [#TEMPSKU] (                     
      [ID]          [INT] IDENTITY(1,1) NOT NULL,                                        
      [Orderkey]    [NVARCHAR] (20)  NULL,  
      [SKU]         [NVARCHAR] (20) NULL,  
      [DropID]      [NVARCHAR] (30)  NULL,    
      [LabelLine]   INT  NULL,      
      [SDESCR]      [NVARCHAR] (60)  NULL,    
      [SSTYLE]      [NVARCHAR] (20)  NULL,  
      [SSIZE]       [NVARCHAR] (20)  NULL,  
      [Barcode]     [NVARCHAR] (80) NULL,           
      [Qty]         INT ,   
      [Retrieve]    [NVARCHAR] (1) default 'N')           
             

INSERT INTO #Result
(
    Col01,
    Col02,
    Col03,
    Col04,
    Col05,
    Col06,
    Col07,
    Col08,
    Col09,
    Col10,
    Col11,
    Col12,
    Col13,
    Col14,
    Col15,
    Col16,
    Col17,
    Col18,
    Col19,
    Col20,
    Col21,
    Col22,
    Col23,
    Col24,
    Col25,
    Col26,
    Col27,
    Col28,
    Col29,
    Col30,
    Col31,
    Col32,
    Col33,
    Col34,
    Col35,
    Col36,
    Col37,
    Col38,
    Col39,
    Col40,
    Col41,
    Col42,
    Col43,
    Col44,
    Col45,
    Col46,
    Col47,
    Col48,
    Col49,
    Col50,
    Col51,
    Col52,
    Col53,
    Col54,
    Col55,
    Col56,
    Col57,
    Col58,
    Col59,
    Col60
)

        SELECT DISTINCT RTRIM(SUBSTRING(ORDERS.consigneekey,5,45)),ISNULL(RTRIM(ORDERS.C_Company),''),ISNULL(RTRIM(ORDERS.C_ADDRESS1),''),
                         ISNULL(RTRIM(ORDERS.C_ADDRESS2),''),--+ISNULL(RTRIM(ORDERS.C_City),'')+ISNULL(RTRIM(ORDERS.C_Zip),''),1,80),
                         ISNULL(RTRIM(ORDERS.ExternOrderkey),''),+ CHAR(13)+      --5        --CS02
                         ISNULL(RTRIM(ORDERS.ExternOrderkey),''),ISNULL(RTRIM(ORDERS.userdefine05),''),ISNULL(RTRIM(ORDERS.userdefine10),''),ISNULL(RTRIM(PACKDETAIL.DropID),''),ISNULL(RTRIM(PACKDETAIL.DropID),''),     --10    
                         CAST(PACKDETAIL.CartonNo AS NVARCHAR(10)), CASE WHEN PACKHEADER.Status = '9' THEN CAST(PACKHEADER.TTLCNTS AS NVARCHAR(5)) ELSE '' END,'','','',     --15    
                        '','','','','',     --20         
                        + CHAR(13) +        
                       '','','','','','','','','','',  --30    
                        '','','','','','','','','','',   --40         
                        '','','','','','','','','','',  --50         
                        '','','','',ISNULL(RTRIM(ORDERS.M_State),''),ISNULL(RTRIM(ORDERS.C_ADDRESS3),''),ISNULL(RTRIM(ORDERS.C_ADDRESS4),''),    --57
                        SUBSTRING(ISNULL(RTRIM(ORDERS.C_City),'')+ISNULL(RTRIM(ORDERS.C_Zip),''),1,80),'',PACKHEADER.Orderkey   --60            --CS02            
            FROM  PACKDETAIL  WITH (NOLOCK)
            JOIN  PACKHEADER  WITH (NOLOCK)  ON (PACKDETAIL.PickSlipNo = PACKHEADER.PickSlipNo)
            JOIN  ORDERS      WITH (NOLOCK)  ON (PACKHEADER.Orderkey = ORDERS.Orderkey)
            JOIN  SKU         WITH (NOLOCK)  ON (PACKDETAIL.Storerkey = SKU.Storerkey)
                                             AND (PACKDETAIL.Sku = SKU.Sku)
            JOIN  PACK        WITH (NOLOCK)  ON (SKU.Packkey = PACK.Packkey)
            WHERE PACKHEADER.Orderkey = @c_Sparm01
            AND   PACKDETAIL.DropID   = CASE WHEN @c_Sparm02 = '' THEN PACKDETAIL.DropID ELSE @c_Sparm02 END
              
           
     
           
   IF @b_debug=1          
   BEGIN          
      SELECT * FROM #Result (nolock)          
   END          
    
    
  DECLARE CUR_RowNoLoop CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
  SELECT DISTINCT col09,col60,col05       
   FROM #Result                 
      
            
   OPEN CUR_RowNoLoop                    
               
   FETCH NEXT FROM CUR_RowNoLoop INTO @c_dropid,@c_OrderKey,@c_externorderkey      
                 
   WHILE @@FETCH_STATUS <> -1               
   BEGIN                   
      IF @b_debug='1'                
      BEGIN                
         PRINT @c_OrderKey                   
      END   
       
        
INSERT INTO #TEMPSKU
(
    Orderkey,
    DropID,
    sku,
    LabelLine,
    SDESCR,
    SSTYLE,
    SSIZE,
    Barcode,
    Qty,
    Retrieve
)

      SELECT DISTINCT PACKHEADER.Orderkey,PACKDETAIL.DropID,PACKDETAIL.sku,TRY_CONVERT(INT,PackDetail.LabelLine),
                      SKU.DESCR,Sku.Style,Sku.Size,Sku.color,  
                     SUM(PACKDETAIL.qty),'N'  
            FROM  PACKDETAIL  WITH (NOLOCK)
            JOIN  PACKHEADER  WITH (NOLOCK)  ON (PACKDETAIL.PickSlipNo = PACKHEADER.PickSlipNo)
            JOIN  ORDERS      WITH (NOLOCK)  ON (PACKHEADER.Orderkey = ORDERS.Orderkey)
            JOIN  SKU         WITH (NOLOCK)  ON (PACKDETAIL.Storerkey = SKU.Storerkey)
                                             AND (PACKDETAIL.Sku = SKU.Sku)
            JOIN  PACK        WITH (NOLOCK)  ON (SKU.Packkey = PACK.Packkey)
            WHERE PACKHEADER.Orderkey = @c_Sparm01
            AND   PACKDETAIL.DropID   = CASE WHEN @c_Sparm02 = '' THEN PACKDETAIL.DropID ELSE @c_Sparm02 END  
            GROUP BY PACKHEADER.Orderkey,PACKDETAIL.DropID,PACKDETAIL.sku,PackDetail.LabelLine,
                      SKU.DESCR,Sku.Style,Sku.Size,Sku.color
            ORDER BY PACKHEADER.Orderkey,PACKDETAIL.DropID,TRY_CONVERT(INT,PackDetail.LabelLine)
        
      SET @c_SDESCR01 = ''  
      SET @c_SDESCR02 = ''  
      SET @c_SDESCR03 = ''  
      SET @c_SDESCR04 = ''  
      SET @c_SDESCR05= ''  
      SET @c_SDESCR06= ''  
      SET @c_SDESCR07= ''  

      SET @c_SSTYLE01 = ''  
      SET @c_SSTYLE02 = ''  
      SET @c_SSTYLE03 = ''  
      SET @c_SSTYLE04 = ''  
      SET @c_SSTYLE05= ''  
      SET @c_SSTYLE06 = ''  
      SET @c_SSTYLE07 = ''  

      SET @c_SSIZE01 = ''  
      SET @c_SSIZE02 = ''  
      SET @c_SSIZE03 = ''  
      SET @c_SSIZE04 = ''  
      SET @c_SSIZE05= ''  
      SET @c_SSIZE06 = ''  
      SET @c_SSIZE07 = ''  
 
      SET @c_Barcode01 = ''  
      SET @c_Barcode02 = ''  
      SET @c_Barcode03 = ''  
      SET @c_Barcode04 = ''  
      SET @c_Barcode05= ''  
      SET @c_Barcode06 = ''  
      SET @c_Barcode07 = ''  
 
      SET @c_SKUQty01 = ''  
      SET @c_SKUQty02 = ''  
      SET @c_SKUQty03 = ''  
      SET @c_SKUQty04 = ''  
      SET @c_SKUQty05 = ''  
      SET @c_SKUQty06 = ''  
      SET @c_SKUQty07 = ''  
 
      SET @n_Labelno01 = 0
      SET @n_Labelno02 = 0
      SET @n_Labelno03 = 0
      SET @n_Labelno04 = 0
      SET @n_Labelno05 = 0
      SET @n_Labelno06 = 0
      SET @n_Labelno07 = 0
     
           
      SELECT @n_CntRec = COUNT (1)  
      FROM #TEMPSKU   
      WHERE Orderkey = @c_OrderKey  
      AND DropID = @c_dropid   
      AND Retrieve = 'N'   
       



      SET @n_TTLpage =  FLOOR(@n_CntRec / @n_MaxLine )  + CASE WHEN @n_CntRec % @n_MaxLine > 0 THEN 1 ELSE 0 END  --CS01

     --SELECT @n_intFlag '@n_intFlag', @n_CntRec '@n_CntRec', @n_TTLpage '@n_TTLpage'
        
      IF @b_debug='1'
      BEGIN
           SELECT * FROM #TEMPSKU
           SELECT @n_TTLpage '@n_TTLpage' , @n_CurrentPage '@n_CurrentPage'
      END
  
     WHILE @n_intFlag <= @n_CntRec             
     BEGIN     

        
      SELECT @c_Sdescr = SDESCR,  
             @c_SStyle = SSTYLE,  
             @c_SSize  = SSIZE,  
             @n_labelline = LabelLine,  
             @n_skuqty = SUM(Qty) ,
             @c_sku  = SKU 
      FROM #TEMPSKU   
      WHERE ID = @n_intFlag  
      GROUP BY SDESCR,SSTYLE, SSIZE, LabelLine,sku  

        
       IF (@n_intFlag%@n_MaxLine) = 1   
       BEGIN          
        SET @c_Sdescr01  = @c_SDESCR  
        SET @c_SSTYLE01  = @c_SStyle  
        SET @n_Labelno01 = @n_labelline  
        SET @c_SSIZE01  = @c_SSize  
        SET @c_SKUQty01 = CONVERT(NVARCHAR(10),@n_skuqty)   
        SET @c_Barcode01 = @c_externorderkey +   @c_sku + CONVERT(NVARCHAR(10),@n_skuqty)    

       END          
        

       ELSE IF (@n_intFlag%@n_MaxLine) = 2  
       BEGIN          
        SET @c_Sdescr02  = @c_SDESCR 
        SET @c_SSTYLE02 = @c_SStyle  
        SET @n_Labelno02 = @n_labelline  
        SET @c_SSIZE02  = @c_SSize  
        SET @c_SKUQty02 = CONVERT(NVARCHAR(10),@n_skuqty)  
        SET @c_Barcode02= @c_externorderkey +   @c_sku + CONVERT(NVARCHAR(10),@n_skuqty)          
       END          
          
       ELSE IF (@n_intFlag%@n_MaxLine) = 3  
       BEGIN              
        SET @c_Sdescr03  = @c_SDESCR   
        SET @c_SSTYLE03 = @c_SStyle  
        SET @n_Labelno03 = @n_labelline  
        SET @c_SSIZE03  = @c_SSize  
        SET @c_SKUQty03 = CONVERT(NVARCHAR(10),@n_skuqty)  
        SET @c_Barcode03 = @c_externorderkey +   @c_sku + CONVERT(NVARCHAR(10),@n_skuqty)         
       END          
            
       ELSE IF (@n_intFlag%@n_MaxLine) = 4  
       BEGIN          
        SET @c_Sdescr04  = @c_SDESCR  
        SET @c_SSTYLE04 = @c_SStyle  
        SET @n_Labelno04 = @n_labelline  
        SET @c_SSIZE04  = @c_SSize  
        SET @c_SKUQty04 = CONVERT(NVARCHAR(10),@n_skuqty)
        SET @c_Barcode04 = @c_externorderkey +   @c_sku + CONVERT(NVARCHAR(10),@n_skuqty)           
       END       
         
       ELSE IF (@n_intFlag%@n_MaxLine) = 5  
       BEGIN          
        SET @c_Sdescr05  = @c_SDESCR  
        SET @c_SSTYLE05 = @c_SStyle  
        SET @n_Labelno05 = @n_labelline  
        SET @c_SSIZE05  = @c_SSize  
        SET @c_SKUQty05 = CONVERT(NVARCHAR(10),@n_skuqty)     
        SET @c_Barcode05 = @c_externorderkey +   @c_sku + CONVERT(NVARCHAR(10),@n_skuqty)      
       END     
         
       ELSE IF (@n_intFlag%@n_MaxLine) = 6  
       BEGIN          
        SET @c_Sdescr06  = @c_SDESCR   
        SET @c_SSTYLE06 = @c_SStyle  
        SET @n_Labelno06 = @n_labelline  
        SET @c_SSIZE06  = @c_SSize  
        SET @c_SKUQty06 = CONVERT(NVARCHAR(10),@n_skuqty)  
        SET @c_Barcode06 = @c_externorderkey +   @c_sku + CONVERT(NVARCHAR(10),@n_skuqty)         
       END        
         
       ELSE IF (@n_intFlag%@n_MaxLine) = 0  
       BEGIN          
        SET @c_Sdescr07  = @c_SDESCR  
        SET @c_SSTYLE07 = @c_SStyle  
        SET @n_Labelno07 = @n_labelline  
        SET @c_SSIZE07  = @c_SSize  
        SET @c_SKUQty07 = CONVERT(NVARCHAR(10),@n_skuqty)    
        SET @c_Barcode07 = @c_externorderkey +   @c_sku + CONVERT(NVARCHAR(10),@n_skuqty)       
       END     
                 
    --END   
           
       UPDATE #Result                    
       SET Col13 = CASE WHEN @n_Labelno01 <> 0 THEN CAST(@n_Labelno01 AS NVARCHAR(10)) ELSE '' END,    
           Col14 = @c_sstyle01,           
           Col15 = @c_SDESCR01, 
           Col16 = @c_SSIZE01,          
           Col17 = @c_SKUQty01,          
           Col18 = @c_Barcode01, 
           Col19 = CASE WHEN @n_Labelno02 <> 0 THEN CAST(@n_Labelno02 AS NVARCHAR(10))  ELSE '' END,    
           Col20 = @c_sstyle02,           
           Col21 = @c_SDESCR02, 
           Col22 = @c_SSIZE02,          
           Col23 = @c_SKUQty02,          
           Col24 = @c_Barcode02,
           Col25 = CASE WHEN @n_Labelno03 <> 0 THEN CAST(@n_Labelno03 AS NVARCHAR(10))  ELSE '' END,    
           Col26 = @c_sstyle03,           
           Col27 = @c_SDESCR03, 
           Col28 = @c_SSIZE03,          
           Col29 = @c_SKUQty03,          
           Col30 = @c_Barcode03, 
           Col31 = CASE WHEN @n_Labelno04 <> 0 THEN CAST(@n_Labelno04 AS NVARCHAR(10))  ELSE '' END,    
           Col32 = @c_sstyle04,           
           Col33 = @c_SDESCR04, 
           Col34 = @c_SSIZE04,          
           Col35 = @c_SKUQty04,          
           Col36 = @c_Barcode04, 
           Col37 = CASE WHEN @n_Labelno05 <> 0 THEN CAST(@n_Labelno05 AS NVARCHAR(10))  ELSE '' END,    
           Col38 = @c_sstyle05,           
           Col39 = @c_SDESCR05, 
           Col40 = @c_SSIZE05,          
           Col41 = @c_SKUQty05,          
           Col42 = @c_Barcode05, 
           Col43 = CASE WHEN @n_Labelno06 <> 0 THEN CAST(@n_Labelno06 AS NVARCHAR(10))  ELSE '' END,    
           Col44 = @c_sstyle06,           
           Col45 = @c_SDESCR06, 
           Col46 = @c_SSIZE06,          
           Col47 = @c_SKUQty06,          
           Col48 = @c_Barcode06, 
           Col49 = CASE WHEN @n_Labelno07 <> 0 THEN CAST(@n_Labelno07 AS NVARCHAR(10))  ELSE '' END,    
           Col50 = @c_sstyle07,           
           Col51 = @c_SDESCR07, 
           Col52 = @c_SSIZE07,          
           Col53 = @c_SKUQty07,          
           Col54 = @c_Barcode07               
       WHERE ID = @n_CurrentPage    
         
         
   IF (@n_intFlag%@n_MaxLine) = 0 AND @n_CurrentPage <> @n_TTLpage--AND (@n_CntRec - 1) <> 0  
   BEGIN  
     SET @n_CurrentPage = @n_CurrentPage + 1  
       
     INSERT INTO #Result (Col01,Col02,Col03,Col04,Col05, Col06,Col07,Col08,Col09                   
                            ,Col10,Col11,Col12,Col13,Col14,Col15,Col16,Col17,Col18,Col19,Col20,Col21,Col22                 
                            ,Col23,Col24,Col25,Col26,Col27,Col28,Col29,Col30,Col31,Col32,Col33,Col34                  
                            ,Col35,Col36,Col37,Col38,Col39,Col40,Col41,Col42,Col43,Col44                   
                            ,Col45,Col46,Col47,Col48,Col49,Col50,Col51,Col52,Col53,Col54                 
                            ,Col55,Col56,Col57,Col58,Col59,Col60)   
      SELECT TOP 1 Col01,Col02,Col03,Col04,Col05, Col06,Col07,Col08,Col09,Col10,                   
                   Col11,Col12,'','','', '','','','','',                
                   '','','','','', '','','','','',                
                   '','','','','', '','','','','',                   
                   '','','','','', '','','','','',                 
                   '','','','',Col55, Col56,Col57,Col58,'',Col60      --CS02  
     FROM  #Result   
  
     
      SET @c_SDESCR01 = ''  
      SET @c_SDESCR02 = ''  
      SET @c_SDESCR03 = ''  
      SET @c_SDESCR04 = ''  
      SET @c_SDESCR05= ''  
      SET @c_SDESCR06= ''  
      SET @c_SDESCR07= ''  

      SET @c_SSTYLE01 = ''  
      SET @c_SSTYLE02 = ''  
      SET @c_SSTYLE03 = ''  
      SET @c_SSTYLE04 = ''  
      SET @c_SSTYLE05= ''  
      SET @c_SSTYLE06 = ''  
      SET @c_SSTYLE07 = ''  

      SET @c_SSIZE01 = ''  
      SET @c_SSIZE02 = ''  
      SET @c_SSIZE03 = ''  
      SET @c_SSIZE04 = ''  
      SET @c_SSIZE05= ''  
      SET @c_SSIZE06 = ''  
      SET @c_SSIZE07 = ''  
 
      SET @c_Barcode01 = ''  
      SET @c_Barcode02 = ''  
      SET @c_Barcode03 = ''  
      SET @c_Barcode04 = ''  
      SET @c_Barcode05= ''  
      SET @c_Barcode06 = ''  
      SET @c_Barcode07 = ''  
 
      SET @c_SKUQty01 = ''  
      SET @c_SKUQty02 = ''  
      SET @c_SKUQty03 = ''  
      SET @c_SKUQty04 = ''  
      SET @c_SKUQty05 = ''  
      SET @c_SKUQty06 = ''  
      SET @c_SKUQty07 = ''  
 
      SET @n_Labelno01 = 0
      SET @n_Labelno02 = 0
      SET @n_Labelno03 = 0
      SET @n_Labelno04 = 0
      SET @n_Labelno05 = 0
      SET @n_Labelno06 = 0
      SET @n_Labelno07 = 0 
    END    
         
    SET @n_intFlag = @n_intFlag + 1     
    --SET @n_CntRec = @n_CntRec - 1   
  
  END      
    
   FETCH NEXT FROM CUR_RowNoLoop INTO  @c_dropid,@c_OrderKey,@c_externorderkey           
          
      END -- While                     
      CLOSE CUR_RowNoLoop                    
      DEALLOCATE CUR_RowNoLoop     
          
SELECT * FROM #Result (nolock)          
              
EXIT_SP:      
    
   SET @d_Trace_EndTime = GETDATE()    
   SET @c_UserName = SUSER_SNAME()    
       
                                    
END -- procedure     

GO