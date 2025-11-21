SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

  
/******************************************************************************/                   
/* Copyright: IDS                                                             */                   
/* Purpose: isp_BT_Bartender_TW_LCT_ship_Label_01                             */                   
/*                                                                            */                   
/* Modifications log:                                                         */                   
/*                                                                            */                   
/* Date       Rev  Author     Purposes                                        */                   
/* 2017-08-11 1.0  CSCHONG    Created (WMS-2413)                              */   
/* 2018-02-07 1.1  CSCHONG    WMS-3896 cater for more than 15 sku (CS01)      */  
/* 2018-03-02 1.2  LZG    INC0146970 - Changed from @c_SKU15 to     */    
/*									     @c_SKU14 (ZG01)											*/    
/******************************************************************************/                  
                    
CREATE PROC [dbo].[isp_BT_Bartender_TW_LCT_ship_Label_02]                                 
(  @c_Sparm1            NVARCHAR(250),                        
   @c_Sparm2            NVARCHAR(250),                        
   @c_Sparm3            NVARCHAR(250),                        
   @c_Sparm4            NVARCHAR(250),                        
   @c_Sparm5            NVARCHAR(250),                        
   @c_Sparm6            NVARCHAR(250),                        
   @c_Sparm7            NVARCHAR(250),                        
   @c_Sparm8            NVARCHAR(250),                        
   @c_Sparm9            NVARCHAR(250),                        
   @c_Sparm10           NVARCHAR(250),                  
   @b_debug             INT = 0                                   
)                                
AS                                
BEGIN                                
   SET NOCOUNT ON                           
   SET ANSI_NULLS OFF                          
   SET QUOTED_IDENTIFIER OFF                           
   SET CONCAT_NULL_YIELDS_NULL OFF                          
  -- SET ANSI_WARNINGS OFF                                
                                        
   DECLARE              
      @c_getPickslipno     NVARCHAR(10),                          
      @c_getlabelno        NVARCHAR(20),            
      @C_RECEIPTKEY        NVARCHAR(11),            
      @C_UCCUserdefined01  NVARCHAR(15),   
      @n_TTLSKUCNT         INT,  
      @n_TTLSKUQTY         INT,   
      @n_Page              INT,  
      @n_ID                INT,   
      @n_RID               INT,   
      @n_MaxLine           INT,         
      @n_MaxLineRec        INT,   
      @c_STCompany         NVARCHAR(45),  
      @c_OHCompany         NVARCHAR(45),  
      @c_OHAddress1        NVARCHAR(45),  
      @c_ExtOrdkey         NVARCHAR(30),  
      @c_Pickslipno        NVARCHAR(20),  
      @c_LPDDeliveryDate   NVARCHAR(10),  
      @c_PDCartonNo        NVARCHAR(10),  
      @c_FacilityAdd       NVARCHAR(30),  
      @c_labelno           NVARCHAR(20),  
      @n_CurrentPage       INT,                --CS01  
      @n_intFlag           INT,                --CS01  
      @n_RecCnt            INT                 --CS01  
        
  DECLARE      
      @c_line01            NVARCHAR(80),   
      @c_SKU               NVARCHAR(80),     --CS01  
      @c_SKUDesr           NVARCHAR(80),     --CS01  
      @n_qty               INT,              --CS01  
      @c_SKU01             NVARCHAR(80),    
      @c_SKUDesr01         NVARCHAR(80),    
      @n_qty01             INT,           
      @c_line02            NVARCHAR(80),   
      @c_SKU02             NVARCHAR(80),  
      @c_SKUDesr02         NVARCHAR(80),  
      @n_qty02             INT,              
      @c_line03            NVARCHAR(80),   
      @c_SKU03             NVARCHAR(80),   
      @c_SKUDesr03         NVARCHAR(80),   
      @n_qty03             INT,           
      @c_line04            NVARCHAR(80),   
      @c_SKU04             NVARCHAR(80),   
      @c_SKUDesr04         NVARCHAR(80),   
      @n_qty04             INT,            
      @c_line05            NVARCHAR(80),    
      @c_SKU05             NVARCHAR(80),  
      @n_qty05             INT,    
      @c_SKUDesr05         NVARCHAR(80),          
      @c_line06            NVARCHAR(80),  
      @c_SKU06             NVARCHAR(80),   
      @c_SKUDesr06         NVARCHAR(80),  
      @n_qty06             INT,           
      @c_line07            NVARCHAR(80),      
      @c_SKU07             NVARCHAR(80),    
      @c_SKUDesr07         NVARCHAR(80),     
      @n_qty07             INT,     
      @c_line08            NVARCHAR(80),  
      @c_SKU08             NVARCHAR(80),    
      @c_SKUDesr08         NVARCHAR(80),   
      @n_qty08             INT,            
      @c_line09            NVARCHAR(80),    
      @c_SKU09             NVARCHAR(80),   
      @c_SKUDesr09         NVARCHAR(80),   
      @n_qty09             INT,          
      @c_line10            NVARCHAR(80),  
      @c_SKU10             NVARCHAR(80),  
      @c_SKUDesr10         NVARCHAR(80),  
      @n_qty10             INT,   
      @c_line11            NVARCHAR(80),  
      @c_SKU11             NVARCHAR(80),  
      @c_SKUDesr11         NVARCHAR(80),  
      @n_qty11             INT,   
      @c_line12            NVARCHAR(80),  
      @c_SKU12             NVARCHAR(80),  
      @c_SKUDesr12         NVARCHAR(80),  
      @n_qty12             INT,    
      @c_line13            NVARCHAR(80),  
      @c_SKU13             NVARCHAR(80),  
      @c_SKUDesr13         NVARCHAR(80),  
      @n_qty13             INT,    
      @c_line14            NVARCHAR(80),  
      @c_SKU14             NVARCHAR(80),  
      @c_SKUDesr14         NVARCHAR(80),  
      @n_qty14             INT,    
      @c_line15            NVARCHAR(80),  
      @c_SKU15             NVARCHAR(80),  
      @c_SKUDesr15         NVARCHAR(80),  
      @n_qty15             INT,  
      @n_ttlPqty           INT  
        
    
 Declare                             
      @c_SQL             NVARCHAR(4000),                  
      @c_SQLSORT         NVARCHAR(4000),                  
      @c_SQLJOIN         NVARCHAR(4000),                      
      @n_TTLpage         INT,  
      @n_CntRec          INT                    --CS01            
            
  DECLARE  @d_Trace_StartTime   DATETIME,             
           @d_Trace_EndTime    DATETIME,            
           @c_Trace_ModuleName NVARCHAR(20),             
           @d_Trace_Step1      DATETIME,             
           @c_Trace_Step1      NVARCHAR(20),            
           @c_UserName         NVARCHAR(20)              
            
   SET @d_Trace_StartTime = GETDATE()            
   SET @c_Trace_ModuleName = ''            
                  
    -- SET RowNo = 0                       
    SET @c_SQL = ''     
    SET @n_ttlPqty = 0             
    SET @n_CurrentPage = 1             --CS01    
    SET @n_intFlag = 1                 --CS01  
    SET @n_RecCnt = 1                  --CS01         
                        
--    IF OBJECT_ID('tempdb..#Result','u') IS NOT NULL          
--      DROP TABLE #Result;          
            
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
            
--      IF OBJECT_ID('tempdb..#CartonContent','u') IS NOT NULL          
--      DROP TABLE #CartonContent;          
          
     CREATE TABLE [#CartonSKUContent] (                       
      [ID]                    [INT] IDENTITY(1,1) NOT NULL,  
      [Pickslipno]            [NVARCHAR] (20)  NULL,  
      cartonno                [NVARCHAR] (10) NULL,    
      [SKU]                   [NVARCHAR] (20) NULL,                                      
      [SDESCR]                [NVARCHAR] (80) NULL,                                                
      [skuqty]                INT NULL,                               
      [Retrieve]              [NVARCHAR] (1) default 'N')                 
                      
                             
      IF @b_debug=1                  
      BEGIN                    
        PRINT 'start'                    
      END            
            
    DECLARE CUR_StartRecLoop CURSOR LOCAL FAST_FORWARD READ_ONLY FOR              
            
       
    SELECT distinct ST.Company,o.C_Company,o.C_Address1,o.ExternOrderKey,ph.PickSlipNo,CONVERT(NVARCHAR(10),lpd.DeliveryDate,126),  
    MIN(pd.CartonNo),(f.Address1+f.Phone1),pd.labelno  
     FROM PackHeader AS ph WITH (NOLOCK)   
     JOIN PackDetail AS pd WITH (NOLOCK) ON pd.PickSlipNo = ph.PickSlipNo   
     JOIN ORDERS AS o WITH (NOLOCK) ON o.OrderKey = ph.OrderKey    
     JOIN Storer ST WITH (NOLOCK) ON ST.storerkey=o.storerkey    
      JOIN FACILITY F WITH (NOLOCK) ON F.facility = O.facility   
      JOIN loadplandetail lpd WITH (NOLOCK) ON lpd.LoadKey=o.LoadKey AND lpd.OrderKey=o.OrderKey  
      WHERE pd.pickslipno =@c_Sparm1  AND pd.labelno = @c_Sparm2    
     GROUP BY ST.Company,o.C_Company,o.C_Address1,o.ExternOrderKey,ph.PickSlipNo,lpd.DeliveryDate,(f.Address1+f.Phone1)  
    ,CONVERT(NVARCHAR(10),lpd.DeliveryDate,126)  ,pd.labelno    
      
            
   OPEN CUR_StartRecLoop                      
                 
   FETCH NEXT FROM CUR_StartRecLoop INTO @c_STcompany,@c_OHCompany,@c_OHAddress1,@c_ExtOrdKey,@c_Pickslipno,@c_LPDDeliveryDate  
                                        ,@c_PDCartonNo,@c_FacilityAdd,@c_labelno       
                                                         
                   
   WHILE @@FETCH_STATUS <> -1                      
   BEGIN             
            
      IF @b_debug=1                  
      BEGIN                    
        PRINT 'Cur start'                    
      END            
            
   INSERT INTO #Result (Col01,Col02,Col03,Col04,Col05, Col06,Col07,Col08,Col09                     
                            ,Col10,Col11,Col12,Col13,Col14,Col15,Col16,Col17,Col18,Col19,Col20,Col21,Col22                   
                            ,Col23,Col24,Col25,Col26,Col27,Col28,Col29,Col30,Col31,Col32,Col33,Col34                    
                            ,Col35,Col36,Col37,Col38,Col39,Col40,Col41,Col42,Col43,Col44                     
                            ,Col45,Col46,Col47,Col48,Col49,Col50,Col51,Col52,Col53,Col54                   
                            ,Col55,Col56,Col57,Col58,Col59,Col60)               
     VALUES(@c_STcompany,@c_OHCompany,@c_OHAddress1,@c_ExtOrdKey,@c_Pickslipno,@c_LPDDeliveryDate,'',            
            '','','','','','',            
            '','','','','','','',             
            '','','','','','','','','','','','','','','','','','','','','','','','','','','','','',''        --(CS01)     
            ,'',@c_PDCartonNo,'',@c_FacilityAdd,'','','','',@c_labelno,'O')            
            
            
   IF @b_debug=1                  
   BEGIN                  
     SELECT * FROM #Result (nolock)                  
   END             
            
   SET @n_MaxLine    = 15  
   SET @n_MaxLineRec = 17  
   SET @n_TTLpage = 1         
      
       
              
   DECLARE CUR_RowNoLoop CURSOR LOCAL FAST_FORWARD READ_ONLY FOR                        
                       
   SELECT DISTINCT col05,col59         
   FROM #Result   
   WHERE col05 = @c_Sparm1   
   AND col59 = @c_Sparm2                 
   ORDER BY col05,col59        
              
   OPEN CUR_RowNoLoop                      
                 
   FETCH NEXT FROM CUR_RowNoLoop INTO @c_getPickslipno,@c_getlabelno  
                   
   WHILE @@FETCH_STATUS <> -1                 
   BEGIN                     
       
                
   INSERT INTO [#CartonSKUContent] (Pickslipno,Cartonno,SKU,SDESCR,skuqty,Retrieve)                            
   SELECT ph.PickSlipNo,pd.cartonno,pd.sku,s.DESCR,pd.Qty,'N'  
      FROM PackHeader AS ph WITH (NOLOCK)   
     JOIN PackDetail AS pd WITH (NOLOCK) ON pd.PickSlipNo = ph.PickSlipNo   
     JOIN ORDERS AS o WITH (NOLOCK) ON o.OrderKey = ph.OrderKey    
     JOIN Storer ST WITH (NOLOCK) ON ST.storerkey=o.storerkey   
     JOIN SKU S WITH (NOLOCK) ON S.StorerKey=pd.StorerKey AND s.sku = PD.SKU  
      WHERE pd.pickslipno =@c_getPickslipno  AND pd.labelno = @c_labelno    
    -- GROUP BY ph.PickSlipNo,pd.cartonno,pd.sku,s.DESCR  
     ORDER BY ph.PickSlipNo,pd.SKU        
                             
       IF @b_debug = '1'                
       BEGIN                
         SELECT 'carton',* FROM [#CartonSKUContent]            
       END                
              
      SET @c_line01     = ''  
      SET @c_SKU01      = ''  
      SET @c_SKUDesr01  = ''  
      SET @n_qty01      = 0         
      SET @c_line02     = ''  
      SET @c_SKU02      = ''  
      SET @c_SKUDesr02  = ''  
      SET @n_qty02      = 0            
      SET @c_line03     = ''  
      SET @c_SKU03      = ''   
      SET @c_SKUDesr03  = ''  
      SET @n_qty03      = 0         
      SET @c_line04     = ''  
      SET @c_SKU04      = ''  
      SET @c_SKUDesr04  = ''  
      SET @n_qty04      = 0          
      SET @c_line05     = ''  
      SET @c_SKU05      = ''  
      SET @n_qty05      = 0  
      SET @c_SKUDesr05  = ''          
      SET @c_line06     = ''  
      SET @c_SKU06      = ''  
      SET @c_SKUDesr06  = ''  
      SET @n_qty06       = 0         
      SET @c_line07     = ''  
      SET @c_SKU07      = ''  
      SET @c_SKUDesr07  = ''  
      SET @n_qty07      = 0   
      SET @c_line08     = ''  
      SET @c_SKU08      = ''    
      SET @c_SKUDesr08  = ''   
      SET @n_qty08       = 0          
      SET @c_line09     = ''    
      SET @c_SKU09      = ''   
      SET @c_SKUDesr09  = ''   
      SET @n_qty09      = 0        
      SET @c_line10     = ''  
      SET @c_SKU10      = ''  
      SET @c_SKUDesr10  = ''  
      SET @n_qty10      = 0   
      SET @c_line11     = ''  
      SET @c_SKU11      = ''  
      SET @c_SKUDesr11  = ''  
      SET @n_qty11      = 0  
      SET @c_line12     = ''  
      SET @c_SKU12      = ''  
      SET @c_SKUDesr12  = ''  
      SET @n_qty12      = 0  
      SET @c_line13     = ''  
      SET @c_SKU13      = ''  
      SET @c_SKUDesr13  = ''  
      SET @n_qty13      = 0  
      SET @c_line14     = ''  
      SET @c_SKU14      = ''  
      SET @c_SKUDesr14  = ''  
      SET @n_qty14      = 0  
      SET @c_line15     = ''  
      SET @c_SKU15      = ''  
      SET @c_SKUDesr15  = ''  
      SET @n_qty15      = 0  
        
        
      SELECT @n_CntRec = COUNT (1)  
      FROM [#CartonSKUContent]  
      WHERE Pickslipno = @c_getPickslipno  
      AND Retrieve = 'N'   
        
      SET @n_TTLpage =  FLOOR(@n_CntRec / @n_MaxLine )    
        
     -- SELECT  @n_CntRec '@n_CntRec',@n_TTLpage '@n_TTLpage'  
                 
   --DECLARE CUR_RowPage CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
   --SELECT DISTINCT ID  
   --FROM [#CartonSKUContent]  
   --Order by ID  
  
   --OPEN CUR_RowPage              
              
   --FETCH NEXT FROM CUR_RowPage INTO  @n_ID    
                 
   --WHILE @@FETCH_STATUS <> -1               
   --BEGIN                   
  
  
    -- BEGIN           
       IF @b_debug = '1'                
       BEGIN               
         SELECT * FROM  #CartonSKUContent  WITH (NOLOCK)  WHERE Retrieve='N'           
                     
       END    
         
     WHILE @n_intFlag<= @n_CntRec  
     BEGIN  
          
  
       SELECT   @c_SKU = c.SKU  
     ,@c_SKUDesr = c.SDESCR      
     ,@n_qty = c.skuqty    
       FROM  #CartonSKUContent c WITH (NOLOCK)   
       WHERE id = @n_intFlag  
              
  
      IF (@n_intFlag%@n_MaxLine) = 1  
      BEGIN  
   SET    @c_SKU01 = @c_SKU  
   SET    @c_SKUDesr01 = @c_SKUDesr   
   SET    @n_qty01 = @n_qty          
    --FROM  #CartonSKUContent c WITH (NOLOCK)                        
   --WHERE c.ID = 1    
       END     
       ELSE IF (@n_intFlag%@n_MaxLine) = 2  
       BEGIN  
    SET     @c_SKU02 = @c_SKU  
    SET     @c_SKUDesr02 = @c_SKUDesr     
    SET     @n_qty02= @n_qty            
    --FROM  #CartonSKUContent c WITH (NOLOCK)                        
    --WHERE c.ID = 2    
       END    
       ELSE IF (@n_intFlag%@n_MaxLine) = 3  
       BEGIN  
   SET    @c_SKU03 = @c_SKU  
   SET    @c_SKUDesr03 = @c_SKUDesr     
   SET    @n_qty03 = @n_qty            
   -- FROM  #CartonSKUContent c WITH (NOLOCK)                        
    --WHERE c.ID = 3    
       END   
          
        ELSE IF (@n_intFlag%@n_MaxLine) = 4  
      BEGIN  
   SET    @c_SKU04 = @c_SKU  
   SET    @c_SKUDesr04 = @c_SKUDesr     
   SET    @n_qty04 = @n_qty            
   -- FROM  #CartonSKUContent c WITH (NOLOCK)                        
    --WHERE c.ID = 4   
       END     
       ELSE IF (@n_intFlag%@n_MaxLine) = 5  
       BEGIN  
   SET    @c_SKU05 = @c_SKU  
   SET    @c_SKUDesr05 = @c_SKUDesr     
   SET    @n_qty05= @n_qty            
   -- FROM  #CartonSKUContent c WITH (NOLOCK)                        
   -- WHERE c.ID = 5    
       END    
       ELSE IF (@n_intFlag%@n_MaxLine) = 6  
       BEGIN  
   SET    @c_SKU06 = @c_SKU  
   SET    @c_SKUDesr06 = @c_SKUDesr     
   SET    @n_qty06 = @n_qty            
   -- FROM  #CartonSKUContent c WITH (NOLOCK)                        
    --WHERE c.ID = 6    
       END   
       ELSE IF (@n_intFlag%@n_MaxLine) = 7  
      BEGIN  
   SET    @c_SKU07 = @c_SKU  
   SET    @c_SKUDesr07 = @c_SKUDesr     
   SET    @n_qty07 = @n_qty            
   -- FROM  #CartonSKUContent c WITH (NOLOCK)                        
    --WHERE c.ID = 7    
       END     
       ELSE IF (@n_intFlag%@n_MaxLine) = 8  
       BEGIN  
   SET    @c_SKU08 = @c_SKU  
   SET    @c_SKUDesr08 = @c_SKUDesr     
   SET    @n_qty08= @n_qty            
   -- FROM  #CartonSKUContent c WITH (NOLOCK)                        
   -- WHERE c.ID = 8    
       END    
       ELSE IF (@n_intFlag%@n_MaxLine) = 9  
       BEGIN  
   SET    @c_SKU09 = @c_SKU  
   SET    @c_SKUDesr09 = @c_SKUDesr     
   SET    @n_qty09 = @n_qty            
   -- FROM  #CartonSKUContent c WITH (NOLOCK)                        
   -- WHERE c.ID = 9    
       END     
      ELSE IF (@n_intFlag%@n_MaxLine) = 10  
      BEGIN  
   SET    @c_SKU10 = @c_SKU  
   SET    @c_SKUDesr10 = @c_SKUDesr     
   SET    @n_qty10 = @n_qty            
   -- FROM  #CartonSKUContent c WITH (NOLOCK)                        
   -- WHERE c.ID = 10    
       END     
       ELSE IF (@n_intFlag%@n_MaxLine) = 11  
       BEGIN  
   SET    @c_SKU11 = @c_SKU  
   SET    @c_SKUDesr11 = @c_SKUDesr     
   SET    @n_qty11 = @n_qty            
    --FROM  #CartonSKUContent c WITH (NOLOCK)                        
   -- WHERE c.ID = 11   
       END    
       ELSE IF(@n_intFlag%@n_MaxLine) = 12  
       BEGIN  
   SET    @c_SKU12 = @c_SKU  
   SET    @c_SKUDesr12 = @c_SKUDesr     
   SET    @n_qty12 = @n_qty            
   -- FROM  #CartonSKUContent c WITH (NOLOCK)                        
   -- WHERE c.ID = 12     
       END   
      ELSE IF (@n_intFlag%@n_MaxLine) = 13  
      BEGIN  
   SET    @c_SKU13 = @c_SKU  
   SET    @c_SKUDesr13 = @c_SKUDesr     
   SET    @n_qty13 = @n_qty            
   -- FROM  #CartonSKUContent c WITH (NOLOCK)                        
    --WHERE c.ID = 13  
       END     
       ELSE IF (@n_intFlag%@n_MaxLine) = 14  
       BEGIN  
   SET    @c_SKU14 = @c_SKU  
   SET    @c_SKUDesr14 = @c_SKUDesr     
   SET    @n_qty14 = @n_qty            
   -- FROM  #CartonSKUContent c WITH (NOLOCK)                        
    --WHERE c.ID = 14  
       END    
       ELSE IF (@n_intFlag%@n_MaxLine) = 0  
       BEGIN  
   SET    @c_SKU15 = @c_SKU  
   SET    @c_SKUDesr15 = @c_SKUDesr     
   SET    @n_qty15 = @n_qty            
   -- FROM  #CartonSKUContent c WITH (NOLOCK)                        
    --WHERE c.ID = 15     
       END    
         
        SET @n_ttlPqty = (@n_qty01+@n_qty02+@n_qty03+@n_qty04+@n_qty05+@n_qty06+@n_qty07+@n_qty08+@n_qty09+@n_qty10+@n_qty11+@n_qty12+@n_qty13+@n_qty14+@n_qty15)  
       --CS01 start  
         
      -- SELECT @n_CurrentPage '@n_CurrentPage',@n_ID '@n_ID'  
         
       IF (@n_RecCnt=@n_MaxLine) OR (@n_intFlag = @n_CntRec)       
       BEGIN  
          
       UPDATE #Result                      
       SET Col07 = @c_SKU01,             
           Col08 = @c_SKUDesr01,             
           Col09 = CASE WHEN @n_qty01 > 0 THEN CONVERT(NVARCHAR(5),@n_qty01) ELSE '' END,            
           Col10 = @c_SKU02,            
           Col11 = @c_SKUDesr02,            
           Col12 = CASE WHEN @n_qty02 > 0 THEN CONVERT(NVARCHAR(5),@n_qty02) ELSE '' END,            
           Col13 = @c_SKU03,    
           Col14 = @c_SKUDesr03,             
           Col15 = CASE WHEN @n_qty03 > 0 THEN CONVERT(NVARCHAR(5),@n_qty03) ELSE '' END,            
           Col16 = @c_SKU04,                   
           Col17 = @c_SKUDesr04,             
           Col18 = CASE WHEN @n_qty04 > 0 THEN CONVERT(NVARCHAR(5),@n_qty04) ELSE '' END,    
           Col19 = @c_SKU05,  
           Col20 = @c_SKUDesr05,  
           Col21 = CASE WHEN @n_qty05 > 0 THEN CONVERT(NVARCHAR(5),@n_qty05) ELSE '' END,  
           Col22 = @c_SKU06,  
           col23 = @c_SKUDesr06,  
           Col24 = CASE WHEN @n_qty06 > 0 THEN CONVERT(NVARCHAR(5),@n_qty06) ELSE '' END,  
           Col25 = @c_SKU07,  
           Col26 = @c_SKUDesr07,  
           col27 = CASE WHEN @n_qty07 > 0 THEN CONVERT(NVARCHAR(5),@n_qty07) ELSE '' END,  
           Col28 = @c_SKU08,  
           Col29 = @c_SKUDesr08,  
           Col30 = CASE WHEN @n_qty08 > 0 THEN CONVERT(NVARCHAR(5),@n_qty08) ELSE '' END,  
           col31 = @c_SKU09,  
           Col32 = @c_SKUDesr09,  
           col33 = CASE WHEN @n_qty09 > 0 THEN CONVERT(NVARCHAR(5),@n_qty09) ELSE '' END,  
           Col34 = @c_SKU10,  
           col35 = @c_SKUDesr10,  
           Col36 = CASE WHEN @n_qty10 > 0 THEN CONVERT(NVARCHAR(5),@n_qty10) ELSE '' END,  
           col37 =  @c_SKU11,  
           Col38 = @c_SKUDesr11,  
           col39 = CASE WHEN @n_qty11 > 0 THEN CONVERT(NVARCHAR(5),@n_qty11) ELSE '' END,  
           col40 =  @c_SKU12,  
           col41 = @c_SKUDesr12,  
           col42 = CASE WHEN @n_qty12 > 0 THEN CONVERT(NVARCHAR(5),@n_qty12) ELSE '' END,  
           col43 =  @c_SKU13,  
           col44 = @c_SKUDesr13,  
           col45 = CASE WHEN @n_qty13 > 0 THEN CONVERT(NVARCHAR(5),@n_qty13) ELSE '' END,  
           col46 =  @c_SKU14,  
           col47 = @c_SKUDesr14,  
           col48 = CASE WHEN @n_qty14 > 0 THEN CONVERT(NVARCHAR(5),@n_qty14) ELSE '' END,  
           col49 =  @c_SKU15,  
           col50 = @c_SKUDesr15,  
           col51 = CASE WHEN @n_qty15 > 0 THEN CONVERT(NVARCHAR(5),@n_qty15) ELSE '' END,  
           col53 = CASE WHEN @n_ttlPqty > 0 THEN CONVERT(NVARCHAR(10), @n_ttlPqty) ELSE '' END  
       WHERE col05 = @c_getPickslipno AND col59 = @c_getlabelno   
       AND id = @n_CurrentPage   
         
       SET @n_RecCnt = 0  
          
       END   
   
       --SELECT @n_RecCnt '@n_RecCnt',@n_ID '@n_ID',@n_CntRec '@n_CntRec'  
        IF @n_RecCnt = 0 AND (@n_intFlag<@n_CntRec)--(@n_intFlag%@n_MaxLine) = 0 AND (@n_intFlag>@n_MaxLine)  
        BEGIN  
            SET @n_CurrentPage = @n_CurrentPage + 1     
              
            INSERT INTO #Result (Col01,Col02,Col03,Col04,Col05, Col06,Col07,Col08,Col09                     
                            ,Col10,Col11,Col12,Col13,Col14,Col15,Col16,Col17,Col18,Col19,Col20,Col21,Col22                   
                            ,Col23,Col24,Col25,Col26,Col27,Col28,Col29,Col30,Col31,Col32,Col33,Col34                    
                            ,Col35,Col36,Col37,Col38,Col39,Col40,Col41,Col42,Col43,Col44                     
                            ,Col45,Col46,Col47,Col48,Col49,Col50,Col51,Col52,Col53,Col54                   
                            ,Col55,Col56,Col57,Col58,Col59,Col60)               
            SELECT TOP 1 Col01,Col02,Col03,Col04,Col05,Col06,'','','','',                   
                   '','','','','', '','','','','',                
                   '','','','','', '','','','','',                
                   '','','','','', '','','','','',                   
                   '','','','','', '','','','','',                 
                   '',Col52,'',Col54,'', '','','',Col59,''  
    FROM  #Result   
    WHERE Col60='O'     
    and col05 = @c_getPickslipno AND col59 = @c_getlabelno                   
           
           SET @c_line01     = ''  
    SET @c_SKU01      = ''  
    SET @c_SKUDesr01  = ''  
    SET @n_qty01      = 0         
    SET @c_line02     = ''  
    SET @c_SKU02      = ''  
    SET @c_SKUDesr02  = ''  
    SET @n_qty02      = 0            
    SET @c_line03     = ''  
    SET @c_SKU03      = ''   
    SET @c_SKUDesr03  = ''  
    SET @n_qty03      = 0         
    SET @c_line04     = ''  
    SET @c_SKU04      = ''  
    SET @c_SKUDesr04  = ''  
    SET @n_qty04      = 0          
    SET @c_line05     = ''  
    SET @c_SKU05      = ''  
    SET @n_qty05      = 0  
    SET @c_SKUDesr05  = ''          
    SET @c_line06     = ''  
    SET @c_SKU06      = ''  
    SET @c_SKUDesr06  = ''  
    SET @n_qty06       = 0         
    SET @c_line07     = ''  
    SET @c_SKU07      = ''  
    SET @c_SKUDesr07  = ''  
    SET @n_qty07      = 0   
    SET @c_line08     = ''  
    SET @c_SKU08      = ''    
    SET @c_SKUDesr08  = ''   
    SET @n_qty08       = 0          
    SET @c_line09     = ''    
    SET @c_SKU09      = ''   
    SET @c_SKUDesr09  = ''   
    SET @n_qty09      = 0        
    SET @c_line10     = ''  
    SET @c_SKU10      = ''  
    SET @c_SKUDesr10  = ''  
    SET @n_qty10      = 0   
    SET @c_line11     = ''  
    SET @c_SKU11      = ''  
    SET @c_SKUDesr11  = ''  
    SET @n_qty11      = 0  
    SET @c_line12     = ''  
    SET @c_SKU12      = ''  
    SET @c_SKUDesr12  = ''  
    SET @n_qty12      = 0  
    SET @c_line13     = ''  
    SET @c_SKU13      = ''  
    SET @c_SKUDesr13  = ''  
    SET @n_qty13      = 0  
    SET @c_line14     = ''  
    SET @c_SKU14      = ''  
    SET @c_SKUDesr14  = ''  
    SET @n_qty14      = 0  
    SET @c_line15     = ''  
    SET @c_SKU15      = ''  
    SET @c_SKUDesr15  = ''  
    SET @n_qty15      = 0  
    --SET @n_RecCnt     = 1  
              
       END         
         
       SET @n_intFlag = @n_intFlag + 1   
       SET @n_RecCnt = @n_RecCnt + 1  
         
         
     END                 
     
     --FETCH NEXT FROM CUR_RowPage INTO @n_ID    
     --END -- While                       
     -- CLOSE CUR_RowPage                      
     -- DEALLOCATE CUR_RowPage      
                 
  -- END        
  FETCH NEXT FROM CUR_RowNoLoop INTO @c_getPickslipno,@c_getlabelno                     
              
      END -- While                       
      CLOSE CUR_RowNoLoop                      
      DEALLOCATE CUR_RowNoLoop                  
               
            
   FETCH NEXT FROM CUR_StartRecLoop INTO @c_STcompany,@c_OHCompany,@c_OHAddress1,@c_ExtOrdKey,@c_Pickslipno,@c_LPDDeliveryDate  
                                        ,@c_PDCartonNo,@c_FacilityAdd ,@c_labelno                   
            
   END -- While                       
   CLOSE CUR_StartRecLoop                      
   DEALLOCATE CUR_StartRecLoop              
         
   SELECT * from #result WITH (NOLOCK)             
            
   EXIT_SP:              
            
   SET @d_Trace_EndTime = GETDATE()            
   SET @c_UserName = SUSER_SNAME()            
               
   EXEC isp_InsertTraceInfo             
      @c_TraceCode = 'BARTENDER',            
      @c_TraceName = 'isp_BT_Bartender_TW_LCT_ship_Label_02',            
      @c_starttime = @d_Trace_StartTime,            
      @c_endtime = @d_Trace_EndTime,            
      @c_step1 = @c_UserName,            
      @c_step2 = '',            
      @c_step3 = '',            
      @c_step4 = '',            
      @c_step5 = '',            
      @c_col1 = @c_Sparm1,             
      @c_col2 = @c_Sparm2,            
      @c_col3 = @c_Sparm3,            
      @c_col4 = @c_Sparm4,            
      @c_col5 = @c_Sparm5,            
      @b_Success = 1,            
      @n_Err = 0,            
      @c_ErrMsg = ''                        
             
                                      
END -- procedure     

GO