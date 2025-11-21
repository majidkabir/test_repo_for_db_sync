SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/                           
/* Copyright: IDS                                                             */                           
/* Purpose: BarTender Filter by ShipperKey                                    */                           
/*                                                                            */                           
/* Modifications log:                                                         */                           
/*                                                                            */                           
/* Date       Rev  Author     Purposes                                        */                           
/* 2019-02-28 1.0  CSCHONG    Created(WMS-8043 )                              */   
/* 2019-07-12 1.1  WLChooi    WMS-9570 - Add new field - Col49 (WL01)         */           
/******************************************************************************/                          
                            
CREATE PROC [dbo].[isp_BT_Bartender_CN_Shipper_Content_Label_Allbirds]                                 
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
                                        
   DECLARE              
                 
      @c_OrderKey        NVARCHAR(10),                              
      @c_ExternOrdKey    NVARCHAR(30),      
      @c_ConsigneeKey    NVARCHAR(45),                       
      @c_GetCartonNo     NVARCHAR(10),                              
      @c_GetExternOrdKey NVARCHAR(30),      
      @c_GetConsigneeKey NVARCHAR(20),           
      @c_STCompany       NVARCHAR(45),    
      @c_STState         NVARCHAR(45),    
      @c_Labelno         NVARCHAR(20),    
      @c_GetLabelNo      NVARCHAR(20),    
      @c_STCity          NVARCHAR(45),    
      @c_STAdd1          NVARCHAR(45),   
      @c_STAdd2          NVARCHAR(45),   
      @c_STAdd3          NVARCHAR(45),   
      @c_STAdd4          NVARCHAR(45),  
      @c_STPhone1        NVARCHAR(45)  
    
 Declare            
              
      @n_intFlag         INT,               
      @n_CntRec          INT,            
      @c_colNo           NVARCHAR(5),            
      @n_cntsku          INT,            
      @c_skuMeasurement  NVARCHAR(5),                       
      @C_BuyerPO         NVARCHAR(20),    
      @c_Getbuyerpo      NVARCHAR(20),                          
      @C_notes2          NVARCHAR(4000),                        
      @c_OrderLineNo     NVARCHAR(5),                        
      @c_SKU             NVARCHAR(20),                        
      @n_Qty             INT,                        
      @c_PackKey         NVARCHAR(10),                        
      @c_UOM             NVARCHAR(10),                        
      @C_PHeaderKey      NVARCHAR(18),                        
      @C_SODestination   NVARCHAR(30),                      
      @n_RowNo           INT,                      
      @n_SumPickDETQTY   INT,     
      @n_SumPackDETQTY   INT,                     
      @n_SumUnitPrice    INT,                    
      @c_SQL             NVARCHAR(4000),                  
      @c_SQLSORT         NVARCHAR(4000),                  
      @c_SQLJOIN         NVARCHAR(4000),                
      @c_Udef04          NVARCHAR(80),                  
      @n_TTLPickQTY      INT,              
      @c_ShipperKey      NVARCHAR(15),            
      @n_MaxLine         INT,            
      @n_TTLpage         INT,            
      @n_CurrentPage     INT,            
      @c_dropid          NVARCHAR(20),            
      @n_ID              INT,            
      @n_TTLLine         INT,            
      @n_TTLQty          INT,          
      @c_OrdUdef03       NCHAR(2),          
      @c_itemclass       NCHAR(4),          
      @c_skuGrp          NCHAR(5),          
      @c_SkuStyle        NCHAR(5),             
      @n_cntOrdUDef04    INT,                  
      @c_getOrdUdef04    NVARCHAR(80),  
      @n_CntLRec         INT        
    
 DECLARE       
      @c_PDSKU1            NVARCHAR(60),         
      @c_Line01            NVARCHAR(10),    
      @c_ColPDQty1         NVARCHAR(5),        
      @c_PDSKU2            NVARCHAR(60),         
      @c_Line02            NVARCHAR(10),    
      @c_ColPDQty2         NVARCHAR(5),              
      @c_PDSKU3            NVARCHAR(60),         
      @c_Line03            NVARCHAR(10),    
      @c_ColPDQty3         NVARCHAR(5),     
      @c_PDSKU4            NVARCHAR(60),         
      @c_Line04            NVARCHAR(10),    
      @c_ColPDQty4         NVARCHAR(5),      
      @c_PDSKU5            NVARCHAR(60),         
      @c_Line05            NVARCHAR(10),    
      @c_ColPDQty5         NVARCHAR(5),     
      @c_PDSKU6            NVARCHAR(60),         
      @c_Line06            NVARCHAR(10),    
      @c_ColPDQty6         NVARCHAR(5),    
      @c_PDSKU7            NVARCHAR(60),         
      @c_Line07            NVARCHAR(10),    
      @c_ColPDQty7         NVARCHAR(5),     
      @c_PDSKU8            NVARCHAR(60),         
      @c_Line08            NVARCHAR(10),    
      @c_ColPDQty8         NVARCHAR(5),  
      @c_col11             NVARCHAR(20),  
      @c_ExtOrdkey         NVARCHAR(20),   
      @c_ExtOrdkey1        NVARCHAR(20),   
      @c_ExtOrdkey2        NVARCHAR(20),   
      @c_ExtOrdkey3        NVARCHAR(20),   
      @c_ExtOrdkey4        NVARCHAR(20),   
      @c_ExtOrdkey5        NVARCHAR(20)    
    
    
DECLARE     
      @c_PDSKU9             NVARCHAR(60),         
      @c_Line09             NVARCHAR(10),    
      @c_ColPDQty9          NVARCHAR(5),    
      @c_PDSKU10            NVARCHAR(60),         
      @c_Line10             NVARCHAR(10),    
      @c_ColPDQty10         NVARCHAR(5),    
  
                 
      @c_ColContentsku     NVARCHAR(20),     
      @c_ColContentDescr   NVARCHAR(60),     
      @c_ColContentqty     NVARCHAR(5),      
      @c_CartonType        NVARCHAR(10),    
      @c_GETCartonType     NVARCHAR(10),    
      @c_cartonno          NVARCHAR(10),
      @c_CartonGID         NVARCHAR(50) --WL01    
                 
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
    SET @n_SumPickDETQTY = 0       
    SET @n_SumPackDETQTY = 0                    
    SET @n_SumUnitPrice = 0                      
                        
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
          
     CREATE TABLE [#CartonContent] (                       
      [ID]          [INT] IDENTITY(1,1) NOT NULL,            
      [Pickslipno]  [NVARCHAR] (10) NULL,                                      
      [Sku]         [NVARCHAR] (20) NULL,    
      [CartonNo]    [INT] NULL,                             
      [TTLPICKQTY]  [INT] NULL,            
      [Retrieve]    [NVARCHAR] (1) default 'N')      
     
     
    CREATE TABLE [#LoadExtOrdKey] (                       
      [LID]          [INT] IDENTITY(1,1) NOT NULL,            
      [loadkey]     [NVARCHAR] (20) NULL,                                      
      [ExtOrdKey]   [NVARCHAR] (20) NULL,             
      [Retrieve]    [NVARCHAR] (1) default 'N') 
          
--      IF OBJECT_ID('tempdb..#PICK','u') IS NOT NULL          
--      DROP TABLE #PICK;          
      IF @b_debug=1                  
      BEGIN                    
        PRINT 'start'                    
      END            
            
    DECLARE CUR_StartRecLoop CURSOR LOCAL FAST_FORWARD READ_ONLY FOR              
            
    SELECT PH.loadkey as ORD_ExternOrdKey,ORD.ConsigneeKey as ORD_ConsigneeKey,          
           ST.Company as STCompany,ISNULL(ST.State,'') as STState,ISNULL(ST.city,'') as STCity,    
           ISNULL(ST.Address1,''),ISNULL(ST.Address2,''),ISNULL(ST.Address3,''),ISNULL(ST.Address4,'')  
           ,ISNULL(ST.phone1,''), PDET.labelno,CONVERT(NVARCHAR(10),PDET.cartonno)
           ,CASE WHEN ISNULL(CL.SHORT,'N') = 'Y' THEN ISNULL(PIF.CartonGID,'') ELSE '' END    --WL01
    FROM ORDERS ORD WITH (NOLOCK)     
    INNER JOIN ORDERDETAIL od WITH (NOLOCK) ON od.orderkey=ORD.orderkey                     
    JOIN PACKHEADER PH WITH (NOLOCK) ON PH.Orderkey = ORD.Orderkey          
    JOIN PACKDETAIL PDET WITH (NOLOCK) ON PDET.Pickslipno = PH.Pickslipno        
    LEFT JOIN STORER ST WITH (NOLOCK) ON ST.StorerKey = ORD.ConsigneeKey   
    LEFT JOIN PACKINFO PIF WITH (NOLOCK) ON PDET.Pickslipno = PIF.Pickslipno AND PDET.CartonNo = PIF.CartonNo           --WL01
    OUTER APPLY (SELECT TOP 1 CL.SHORT--, CL.LONG, CL.UDF01, CL.UDF02, CL.UDF03, CL.CODE2                               --WL01
                 FROM CODELKUP CL WITH (NOLOCK)                                                                         --WL01
                 WHERE (CL.LISTNAME = 'BARCODELEN' AND CL.STORERKEY = ORD.STORERKEY AND CL.CODE = 'SUPERHUB' AND        --WL01
                (CL.CODE2 = ORD.FACILITY OR CL.CODE2 = '') ) ORDER BY CASE WHEN CL.CODE2 = '' THEN 2 ELSE 1 END ) AS CL --WL01 
    WHERE ORD.loadkey = @c_Sparm1 AND      
    ORD.orderkey= @c_Sparm2     
    --WHERE PDET.Pickslipno = @c_Sparm1                                          
    AND PDET.Cartonno >= CONVERT(INT,@c_Sparm5)                                
    AND PDET.Cartonno <= CONVERT(INT,@c_Sparm6)                                
    GROUP BY PH.loadkey ,ORD.ConsigneeKey ,          
           ST.Company,ST.State ,ST.city,    
           ST.Address1,ST.Address2,ST.Address3,ST.Address4,ST.phone1,  
           PDET.labelno,CONVERT(NVARCHAR(10),PDET.cartonno),
           ISNULL(PIF.CartonGID,''), ISNULL(CL.SHORT,'N') --WL01   
    UNION  
    SELECT PH.loadkey as ORD_ExternOrdKey,ORD.ConsigneeKey as ORD_ConsigneeKey,          
           ST.Company as STCompany,ISNULL(ST.State,'') as STState,ISNULL(ST.city,'') as STCity,    
           ISNULL(ST.Address1,''),ISNULL(ST.Address2,''),ISNULL(ST.Address3,''),ISNULL(ST.Address4,'')  
           ,ISNULL(ST.phone1,''), PDET.labelno,CONVERT(NVARCHAR(10),PDET.cartonno)
           ,CASE WHEN ISNULL(CL.SHORT,'N') = 'Y' THEN ISNULL(PIF.CartonGID,'') ELSE '' END   
    FROM ORDERS ORD WITH (NOLOCK)     
    INNER JOIN ORDERDETAIL od WITH (NOLOCK) ON od.orderkey=ORD.orderkey                     
    JOIN PACKHEADER PH WITH (NOLOCK) ON PH.loadkey = ORD.loadkey          
    JOIN PACKDETAIL PDET WITH (NOLOCK) ON PDET.Pickslipno = PH.Pickslipno        
    LEFT JOIN STORER ST WITH (NOLOCK) ON ST.StorerKey = ORD.ConsigneeKey 
    LEFT JOIN PACKINFO PIF WITH (NOLOCK) ON PDET.Pickslipno = PIF.Pickslipno AND PDET.CartonNo = PIF.CartonNo           --WL01   
    OUTER APPLY (SELECT TOP 1 CL.SHORT--, CL.LONG, CL.UDF01, CL.UDF02, CL.UDF03, CL.CODE2                               --WL01
                 FROM CODELKUP CL WITH (NOLOCK)                                                                         --WL01
                 WHERE (CL.LISTNAME = 'BARCODELEN' AND CL.STORERKEY = ORD.STORERKEY AND CL.CODE = 'SUPERHUB' AND        --WL01
                (CL.CODE2 = ORD.FACILITY OR CL.CODE2 = '') ) ORDER BY CASE WHEN CL.CODE2 = '' THEN 2 ELSE 1 END ) AS CL --WL01 
    WHERE ORD.loadkey = @c_Sparm1   
    --AND  ORD.orderkey= @c_Sparm2     
    --WHERE PDET.Pickslipno = @c_Sparm1                                          
    AND PDET.Cartonno >= CONVERT(INT,@c_Sparm5)                                
    AND PDET.Cartonno <= CONVERT(INT,@c_Sparm6)    
    AND ISNULL(PH.Orderkey,'') = ''                              
    GROUP BY PH.loadkey ,ORD.ConsigneeKey ,          
             ST.Company,ST.State ,ST.city,    
             ST.Address1,ST.Address2,ST.Address3,ST.Address4,ST.phone1,  
             PDET.labelno,CONVERT(NVARCHAR(10),PDET.cartonno),
             ISNULL(PIF.CartonGID,''), ISNULL(CL.SHORT,'N') --WL01        
            
   OPEN CUR_StartRecLoop                      
                 
   FETCH NEXT FROM CUR_StartRecLoop INTO @c_ExternORDKey,@C_consigneeKey,@C_STCompany,@C_STState,@C_STCity,@c_STAdd1  
                   ,@c_STAdd2,@c_STAdd3,@c_STAdd4,@c_STPhone1,@c_labelno,@c_cartonno,@c_CartonGID          --WL01     
                   
   WHILE @@FETCH_STATUS <> -1                      
   BEGIN             
            
      IF @b_debug=1                  
      BEGIN                    
        PRINT 'Cur start'                    
      END            
            
      INSERT INTO #Result   (Col01,Col02,Col03,Col04,Col05, Col06,Col07,Col08,Col09                     
                            ,Col10,Col11,Col12,Col13,Col14,Col15,Col16,Col17,Col18,Col19,Col20,Col21,Col22                   
                            ,Col23,Col24,Col25,Col26,Col27,Col28,Col29,Col30,Col31,Col32,Col33,Col34                    
                            ,Col35,Col36,Col37,Col38,Col39,Col40,Col41,Col42,Col43,Col44                     
                            ,Col45,Col46,Col47,Col48,Col49,Col50,Col51,Col52,Col53,Col54                   
                            ,Col55,Col56,Col57,Col58,Col59,Col60)               
       VALUES(@c_labelno,@c_ConsigneeKey,@c_STCompany,@c_STState,@c_STCity,@c_STAdd1,             
              @c_STAdd2,@c_STAdd3,@c_STAdd4,@c_STPhone1,@c_cartonno,@c_ExternORDKey,'','','','','','','','',           
              '','','','','','','','','','','','','','','','','','','','','','','','','','','','',@c_CartonGID,'' --WL01           
              ,'','','','','','','','','','O')            
            
            
   IF @b_debug=1                  
   BEGIN                  
     SELECT * FROM #Result (nolock)                  
   END             
            
   SET @n_MaxLine = 10         
   SET @n_TTLpage = 1             
   SET @n_CurrentPage = 1            
   SET @n_intFlag = 1            
   SET @n_TTLLIne = 0            
   SET @n_TTLQty = 0      
              
   DECLARE CUR_RowNoLoop CURSOR LOCAL FAST_FORWARD READ_ONLY FOR                        
                       
   SELECT DISTINCT col01,col11,col12        
   FROM #Result                   
   WHERE Col60 = 'O'             
              
   OPEN CUR_RowNoLoop                      
                 
   FETCH NEXT FROM CUR_RowNoLoop INTO @c_Getlabelno,@c_GetCartonNo,@c_GetExternORDKey  
                   
   WHILE @@FETCH_STATUS <> -1                 
   BEGIN
      SET @n_SumPackDETQTY = 0  
      SET @n_SumPickDETQTY = 0  
      SET @c_col11 = ''  
          
      SELECT @n_SumPackDETQTY = SUM(PD.Qty)    
      FROM PACKHEADER PH WITH (NOLOCK) --ON PH.loadKey = OH.loadKey    
      JOIN PackDetail PD WITH (NOLOCK) ON PD.Pickslipno =PH.Pickslipno   
      where PH.LoadKey=@c_GetExternORDKey    
      AND ISNULL(PH.OrderKey,'') = @c_Sparm2  
      AND PD.Cartonno <= CONVERT(INT,@c_GetCartonNo)  
       
     IF ISNULL(@n_SumPackDETQTY,0) = 0  
     BEGIN  
        SELECT  @n_SumPackDETQTY = SUM(PD.Qty)    
        FROM PACKHEADER PH WITH (NOLOCK) --ON PH.loadKey = OH.loadKey    
        JOIN PackDetail PD WITH (NOLOCK) ON PD.Pickslipno =PH.Pickslipno   
        where PH.LoadKey=@c_GetExternORDKey    
        --AND PD.Cartonno >= CONVERT(INT,@c_Sparm2)    
        AND PD.Cartonno <= CONVERT(INT,@c_GetCartonNo)  
        AND ISNULL(PH.OrderKey,'') = ''   
     END  
       
     SELECT @n_SumPickDETQTY = SUM(PIDET.Qty)  
     FROM PICKHEADER PIH WITH (NOLOCK)   
     JOIN PICKDETAIL PIDET WITH (NOLOCK) ON PIDET.OrderKey = PIH.OrderKey  
     --WHERE PIH.PickHeaderKey =  @c_Sparm1  
     WHERE PIH.externorderkey =  @c_GetExternORDKey  
     and ISNULL(PIH.OrderKey,'') = @c_Sparm2  
      
     IF ISNULL(@n_SumPickDETQTY,0) = 0  
     BEGIN  
  
       --SELECT  @n_SumPickDETQTY = SUM(PIDET.Qty)  
       --FROM PICKHEADER PIH WITH (NOLOCK)   
       --JOIN PICKDETAIL PIDET WITH (NOLOCK) ON PIDET.OrderKey = PIH.OrderKey  
       --WHERE PIH.externorderkey =  @c_GetExternORDKey  
       --and ISNULL(PIH.OrderKey,'') = ''  
  
       SELECT  @n_SumPickDETQTY = SUM(PIDET.Qty)  
       FROM PICKDETAIL PIDET WITH (NOLOCK)  
       WHERE OrderKey in (select orderkey From orders (nolock) where loadkey =@c_GetExternORDKey)  
     END  
  
    --select @n_SumPackDETQTY '@n_SumPackDETQTY',@n_SumPickDETQTY '@n_SumPickDETQTY',@c_col11 '@c_col11'  
  
     IF @n_SumPackDETQTY = @n_SumPickDETQTY  
     BEGIN  
        SET @c_col11 = @c_GetCartonNo + '/' + @c_GetCartonNo  
     END  
  
   DELETE  #CartonContent    
            
   INSERT INTO #CartonContent (Pickslipno,Sku,CartonNo,TTLPICKQTY)            
                  
   SELECT  ph.PickSlipNo    
          ,pd.sku    
          ,pd.CartonNo    
          ,SUM(DISTINCT pd.qty)        
   FROM   orderdetail orddet WITH (NOLOCK)      
          join packheader ph WITH (NOLOCK) ON PH.Orderkey = orddet.Orderkey            
          JOIN packdetail pd WITH (NOLOCK) ON PH.Pickslipno = PD.Pickslipno AND pd.sku=orddet.sku        
          JOIN sku s WITH (NOLOCK)        
          ON  s.sku = orddet.sku        
          AND             s.StorerKey = orddet.Storerkey        
   WHERE  pd.LabelNo = @c_Getlabelno    
   AND PD.Cartonno = CONVERT(INT,@c_GetCartonNo)  
   GROUP BY   ph.PickSlipNo    
             ,pd.sku    
             ,pd.CartonNo   
  UNION  
  SELECT   ph.PickSlipNo    
          ,pd.sku    
          ,pd.CartonNo    
          ,SUM(DISTINCT pd.qty)        
   FROM   orderdetail orddet WITH (NOLOCK)      
   JOIN ORDERS OH WITH (NOLOCK) ON OH.Orderkey = orddet.orderkey    
   join packheader ph WITH (NOLOCK) ON PH.loadkey = OH.loadkey            
   JOIN packdetail pd WITH (NOLOCK) ON PH.Pickslipno = PD.Pickslipno AND pd.sku=orddet.sku        
   JOIN sku s WITH (NOLOCK)        
               ON  s.sku = orddet.sku        
   AND             s.StorerKey = orddet.Storerkey        
   WHERE  pd.LabelNo = @c_Getlabelno    
   AND PD.Cartonno = CONVERT(INT,@c_GetCartonNo)  
   AND ISNULL(ph.orderkey,'') = ''  
   GROUP BY   ph.PickSlipNo    
             ,pd.sku    
             ,pd.CartonNo  
                             
     
      
  --  DELETE #LoadExtOrdKey  
   IF ISNULL(@c_Sparm2,'') = ''  
   BEGIN  
      IF NOT EXISTS (SELECT 1 FROM #LoadExtOrdKey  
                     where loadkey = @c_GetExternORDKey)  
      BEGIN          
         INSERT INTO #LoadExtOrdKey (loadkey, ExtOrdKey)  
         SELECT DISTINCT  TOP 5 loadkey,externorderkey  
         FROM ORDERS (NOLOCK)  
         WHERE loadkey =    @c_GetExternORDKey     
         group by loadkey,externorderkey      
      END  
   END  
   ELSE  
   BEGIN  
      IF NOT EXISTS (SELECT 1 FROM #LoadExtOrdKey)  
      BEGIN          
         INSERT INTO #LoadExtOrdKey (loadkey, ExtOrdKey)  
         SELECT DISTINCT loadkey,externorderkey  
         FROM ORDERS (NOLOCK)  
         WHERE orderkey =    @c_Sparm2     
         group by loadkey,externorderkey      
      END  
   END  

   IF @b_debug = '1'                
   BEGIN                
      SELECT 'carton',* FROM #CartonContent   
      select 'load',* FROM #LoadExtOrdKey           
   END   
              
      SET @c_colno=''            
                 
      SET @c_PDSKU1             =''        
      SET @c_Line01             =''    
      SET @c_ColPDQty1          =''    
      SET @c_PDSKU2             =''         
      SET @c_Line02             =''      
      SET @c_ColPDQty2          =''               
      SET @c_PDSKU3             =''          
      SET @c_Line03             =''      
      SET @c_ColPDQty3          =''      
      SET @c_PDSKU4             =''           
      SET @c_Line04             =''      
      SET @c_ColPDQty4          =''      
      SET @c_PDSKU5             =''       
      SET @c_Line05             =''      
      SET @c_ColPDQty5          =''       
      SET @c_PDSKU6             =''           
      SET @c_Line06             =''      
      SET @c_ColPDQty6          =''      
      SET @c_PDSKU7             =''           
      SET @c_Line07             =''      
      SET @c_ColPDQty7          =''      
      SET @c_PDSKU8             =''           
      SET @c_Line08             =''      
      SET @c_ColPDQty8          =''      
      SET @c_PDSKU9             =''        
      SET @c_Line09             =''    
      SET @c_ColPDQty9          =''    
      SET @c_PDSKU10            =''         
      SET @c_Line10             =''      
      SET @c_ColPDQty10         =''    
      SET @c_ExtOrdkey1         =''   
      SET @c_ExtOrdkey2         =''  
      SET @c_ExtOrdkey3         =''  
      SET @c_ExtOrdkey4         =''  
      SET @c_ExtOrdkey5         =''                
                 
      SELECT @n_CntRec = count(1)             
      FROM #CartonContent            
      WHERE Retrieve = 'N'        
    
      SELECT @n_CntLRec = COUNT(1)  
      FROM #LoadExtOrdKey      
      WHERE Retrieve = 'N'  
     
                     
    SET @n_TTLpage =  FLOOR(@n_CntRec / @n_MaxLine ) + CASE WHEN @n_CntRec % @n_MaxLine > 0 THEN 1 ELSE 0 END           
       
    IF @b_debug='1'            
    BEGIN            
       PRINT ' Rec Count : ' + convert(nvarchar(15),@n_CntRec)            
       PRINT ' TTL Page NO : ' + convert(nvarchar(15),@n_TTLpage)            
       PRINT ' Current Page NO : ' + convert(nvarchar(15),@n_CurrentPage)          
       PRINT '@n_intFlag : ' + + convert(nvarchar(15),@n_intFlag)        
       PRINT '@n_intFlag%Maxline : ' + + convert(nvarchar(15),(@n_intFlag%@n_MaxLine))    
    END     
   
     WHILE (@n_intFlag <=@n_CntRec)            
                  
     BEGIN            
                     
       IF @b_debug = '1'                
       BEGIN               
         SELECT * FROM  #CartonContent  WITH (NOLOCK)              
         PRINT ' update for column no : ' + @c_Colno + 'with ID ' + convert(nvarchar(2),@n_intFlag)            
       END                
           
       IF @n_intFlag > @n_MaxLine  and (@n_intFlag%@n_MaxLine) = 1    
       BEGIN            
   
          SET @n_CurrentPage = @n_CurrentPage + 1     
         
          IF @b_debug = '1'                
          BEGIN    
            PRINT 'Start page : ' + convert(nvarchar(5),@n_CurrentPage)      
            PRINT 'Total page : ' + convert(nvarchar(5),@n_TTLpage)      
          END    
    
       IF (@n_CurrentPage>@n_TTLpage)     
       BREAK;            
            
       INSERT INTO #Result (Col01,Col02,Col03,Col04,Col05, Col06,Col07,Col08,Col09                     
                            ,Col10,Col11,Col12,Col13,Col14,Col15,Col16,Col17,Col18,Col19,Col20,Col21,Col22                   
                            ,Col23,Col24,Col25,Col26,Col27,Col28,Col29,Col30,Col31,Col32,Col33,Col34                    
                            ,Col35,Col36,Col37,Col38,Col39,Col40,Col41,Col42,Col43,Col44                     
                            ,Col45,Col46,Col47,Col48,Col49,Col50,Col51,Col52,Col53,Col54                   
                            ,Col55,Col56,Col57,Col58,Col59,Col60)            
       VALUES(@c_labelno,@c_ConsigneeKey,@c_STCompany,@c_STState,@c_STCity,@c_STAdd1,             
              @c_STAdd2,@c_STAdd3,@c_STAdd4,@c_STPhone1,@c_cartonno,@c_ExternORDKey,'','','','','','','','',            
              '','','','','','','','','','',  
              '','','','','','','','','','',  
              '','','','','','','','',@c_CartonGID,''       --WL01      
              ,'','','','','','','','','','O')            
                  
                   
       IF @b_debug='1'            
       BEGIN            
         SELECT '1111',convert(nvarchar(5),@n_CurrentPage) as CurrentPage,* from #Result            
       END            
                
      SET @c_PDSKU1             =''        
      SET @c_Line01             =''    
      SET @c_ColPDQty1          =''    
      SET @c_PDSKU2             =''         
      SET @c_Line02             =''      
      SET @c_ColPDQty2          =''               
      SET @c_PDSKU3             =''          
      SET @c_Line03             =''      
      SET @c_ColPDQty3          =''      
      SET @c_PDSKU4             =''           
      SET @c_Line04             =''      
      SET @c_ColPDQty4          =''      
      SET @c_PDSKU5             =''       
      SET @c_Line05             =''      
      SET @c_ColPDQty5          =''       
      SET @c_PDSKU6             =''           
      SET @c_Line06             =''      
      SET @c_ColPDQty6          =''      
      SET @c_PDSKU7             =''           
      SET @c_Line07             =''      
      SET @c_ColPDQty7          =''      
      SET @c_PDSKU8             =''           
      SET @c_Line08             =''      
      SET @c_ColPDQty8          =''      
      SET @c_PDSKU9             =''        
      SET @c_Line09             =''    
      SET @c_ColPDQty9          =''    
      SET @c_PDSKU10            =''         
      SET @c_Line10             =''      
      SET @c_ColPDQty10         =''                  
   
    END                
            
       SET @n_TTLLine = 0            
       SET @n_Qty = 0            
                   
        If @b_debug='1'    
       BEGIN    
          PRINT ' get record no : ' + convert(nchar(5),@n_intFlag)    
       END    
          
      SELECT @c_ColContentsku = Sku,     
             @c_ColContentqty =  convert(nchar(5),TTLPICKQTY)  
       FROM  #CartonContent c WITH (NOLOCK)                        
       WHERE c.ID = @n_intFlag      
       AND Retrieve='N'         
                
       If @b_debug= '1'    
       BEGIN     
         PRINT '(@n_intFlag%@n_MaxLine) : '+ convert(nchar(10),(@n_intFlag%@n_MaxLine))          
       END    
           
       --IF @n_intFlag = 1 or @n_intFlag = 16 or @n_intFlag = 31 or @n_intFlag = 46 --(CS04)           
       IF (@n_intFlag%@n_MaxLine) = 1     
       BEGIN     
          
        SET @c_PDSKU1         = @c_ColContentsku        
        SET @c_Line01         = CONVERT(NVARCHAR(10),@n_intFlag  )  
        SET @c_ColPDQty1      = @c_ColContentqty            
       END            
          
       --ELSE IF @n_intFlag = 2 OR @n_intFlag = 17 OR @n_intFlag = 32 OR @n_intFlag = 47  --(CS04)         
       ELSE IF (@n_intFlag%@n_MaxLine) = 2    
       BEGIN        
           
        SET @c_PDSKU2         = @c_ColContentsku        
        SET @c_Line02         = CONVERT(NVARCHAR(10),@n_intFlag  )    
        SET @c_ColPDQty2      = @c_ColContentqty            
       END            
          
       --ELSE IF @n_intFlag = 3 OR @n_intFlag = 18 OR @n_intFlag = 33 OR @n_intFlag = 48    --(CS04)         
       ELSE IF (@n_intFlag%@n_MaxLine) = 3    
       BEGIN                
        SET @c_PDSKU3        = @c_ColContentsku        
        SET @c_Line03        = CONVERT(NVARCHAR(10),@n_intFlag  )     
        SET @c_ColPDQty3     = @c_ColContentqty            
       END            
          
       --ELSE IF @n_intFlag = 4 OR @n_intFlag = 19 OR @n_intFlag = 34 OR @n_intFlag = 49 --(CS04)            
       ELSE IF (@n_intFlag%@n_MaxLine) = 4    
       BEGIN            
        SET @c_PDSKU4     = @c_ColContentsku        
        SET @c_Line04     = CONVERT(NVARCHAR(10),@n_intFlag  )     
        SET @c_ColPDQty4  = @c_ColContentqty            
       END            
          
      -- ELSE IF @n_intFlag = 5 OR @n_intFlag = 20 OR @n_intFlag = 35  OR @n_intFlag = 50 --(CS04)            
       ELSE IF (@n_intFlag%@n_MaxLine) = 5    
       BEGIN            
        SET @c_PDSKU5     = @c_ColContentsku        
        SET @c_Line05     = CONVERT(NVARCHAR(10),@n_intFlag  )   
        SET @c_ColPDQty5  = @c_ColContentqty             
       END            
          
       --ELSE IF @n_intFlag = 6 OR @n_intFlag = 21 OR @n_intFlag = 36  OR @n_intFlag = 51  --(CS04)           
       ELSE IF (@n_intFlag%@n_MaxLine) = 6    
       BEGIN            
        SET @c_PDSKU6     = @c_ColContentsku        
        SET @c_Line06     = CONVERT(NVARCHAR(10),@n_intFlag  )     
        SET @c_ColPDQty6  = @c_ColContentqty             
       END            
                 
       --ELSE IF @n_intFlag = 7 OR @n_intFlag = 22 OR @n_intFlag = 37 OR @n_intFlag = 52  --(CS04)            
       ELSE IF (@n_intFlag%@n_MaxLine) = 7    
       BEGIN            
        SET @c_PDSKU7     = @c_ColContentsku        
        SET @c_Line07     = CONVERT(NVARCHAR(10),@n_intFlag  )   
        SET @c_ColPDQty7  = @c_ColContentqty             
       END            
          
       --ELSE IF @n_intFlag = 8 OR @n_intFlag = 23 OR @n_intFlag = 38 OR @n_intFlag = 53  --(CS04)            
       ELSE IF (@n_intFlag%@n_MaxLine) = 8    
       BEGIN            
        SET @c_PDSKU8     = @c_ColContentsku        
        SET @c_Line08     = CONVERT(NVARCHAR(10),@n_intFlag  )     
        SET @c_ColPDQty8  = @c_ColContentqty            
       END            
          
       --ELSE IF @n_intFlag = 9 OR @n_intFlag = 24 OR @n_intFlag = 39 OR @n_intFlag = 54  --(CS04)            
       ELSE IF (@n_intFlag%@n_MaxLine) = 9    
       BEGIN            
        SET @c_PDSKU9     = @c_ColContentsku        
       SET @c_Line09     = CONVERT(NVARCHAR(10),@n_intFlag  )   
        SET @c_ColPDQty9  = @c_ColContentqty             
       END    
            
       --ELSE IF @n_intFlag = 10 OR @n_intFlag = 25 OR @n_intFlag = 40  OR @n_intFlag = 55  --(CS04)           
       ELSE IF (@n_intFlag%@n_MaxLine) = 0    
       BEGIN            
        SET @c_PDSKU10      = @c_ColContentsku        
        SET @c_Line10       = CONVERT(NVARCHAR(10),@n_intFlag  )    
        SET @c_ColPDQty10   = @c_ColContentqty            
       END      
    
       SET @n_TTLQty = 0    
    
       SELECT @n_TTLQty = SUM(TTLPICKQTY)    
       FROM  #CartonContent c WITH (NOLOCK)           
           
  -- select @c_Line02 '@c_Line02'  
  
  --select @c_col11 '@c_col11'  
            
       UPDATE #Result                      
       SET Col11 = CASE WHEN ISNULL(@c_col11,'') <> '' THEN @c_col11 ELSE Col11 END,--Col11 + @c_col11,  
           Col13 = CASE WHEN @c_Line01 >0 THEN CAST(@c_Line01 AS NVARCHAR(5)) ELSE '' END,      
           Col14 = @c_PDSKU1,                      
           Col15 = TRIM(@c_ColPDQty1),   
           Col16 = @c_Line02,                   
           Col17 = @c_PDSKU2,                      
           Col18 = TRIM(@c_ColPDQty2),   
           Col19 = @c_Line03,           
           Col20 = @c_PDSKU3,                    
           Col21 = TRIM(@c_ColPDQty3),   
           Col22 = @c_Line04,            
           Col23 = @c_PDSKU4,                        
           Col24 = TRIM(@c_ColPDQty4),   
           Col25 = @c_Line05,           
           Col26 = @c_PDSKU5,                                          
           Col27 = TRIM(@c_ColPDQty5),   
           Col28 = @c_Line06,    
           Col29 = @c_PDSKU6,                                  
           Col30 = TRIM(@c_ColPDQty6),   
           Col31 = @c_Line07,                   
           Col32 = @c_PDSKU7,                                   
           Col33 = TRIM(@c_ColPDQty7),  
           Col34 = @c_Line08,             
           Col35 = @c_PDSKU8,                               
           Col36 = TRIM(@c_ColPDQty8),    
           Col37 = @c_Line09,          
           Col38 = @c_PDSKU9,                          
           Col39 = TRIM(@c_ColPDQty9),    
           Col40 = @c_Line10,          
           Col41 = @c_PDSKU10,                               
           Col42 = TRIM(@c_ColPDQty10),    
           Col43 = N'(' + convert(nvarchar(10),@n_TTLQty) + N'件)'  --WL01
       WHERE ID = @n_CurrentPage           
    
       UPDATE  #CartonContent    
       SET Retrieve ='Y'    
       WHERE ID= @n_intFlag     
                        
            
       SET @n_intFlag = @n_intFlag + 1      
    
     IF @n_intFlag > @n_CntRec and @n_CntLRec = 0  
     BEGIN    
       BREAK;    
     END          
            
     IF @b_debug = '1'            
     BEGIN            
      SELECT convert(nvarchar(3),@n_intFlag),* FROM #Result            
     END            
                             
             
    IF @b_debug='1'          
    BEGIN          
      SELECT 'chk', * from #Result          
    END                  
  END   
  
  SET @n_intFlag = 1  
    
  WHILE (@n_intFlag <=@n_CntLRec)            
                  
     BEGIN                       
            
       SET @n_TTLLine = 0            
       SET @n_Qty = 0            
                   
       If @b_debug='1'    
       BEGIN    
          PRINT ' get L record no : ' + convert(nchar(5),@n_intFlag)    
       END         
      
    SELECT @c_externordkey = ExtOrdKey   
    FROM #LoadExtOrdKey   
    WHERE LID = @n_intFlag      
       AND Retrieve='N'   
  
    IF @n_intFlag = 1  
    BEGIN  
      SET @c_ExtOrdkey1 = @c_externordkey  
    END  
    ELSE IF @n_intFlag = 2  
    BEGIN  
     SET @c_ExtOrdkey2 = @c_externordkey  
    END  
    ELSE IF @n_intFlag = 3  
    BEGIN  
     SET @c_ExtOrdkey3 = @c_externordkey  
    END  
    ELSE IF @n_intFlag = 4  
    BEGIN  
     SET @c_ExtOrdkey4 = @c_externordkey  
    END  
    ELSE IF @n_intFlag = 5  
    BEGIN  
     SET @c_ExtOrdkey5 = @c_externordkey  
    END  
  
    --select @c_ExtOrdkey1 '@c_ExtOrdkey1',@c_ExtOrdkey2 '@c_ExtOrdkey2'  
                        
      UPDATE #Result                      
      SET Col44 = @c_ExtOrdkey1,  
          Col45 = @c_ExtOrdkey2,  
          Col46 = @c_ExtOrdkey3,  
          Col47 = @c_ExtOrdkey4,  
          Col48 = @c_ExtOrdkey5  
       WHERE ID = @n_CurrentPage     
      
   -- select * from #Result        
    
     UPDATE #LoadExtOrdKey    
     SET Retrieve ='Y'    
     WHERE LID= @n_intFlag     
                        
            
     SET @n_intFlag = @n_intFlag + 1      
    
     IF @n_intFlag > @n_CntLRec    
     BEGIN    
       BREAK;    
     END          
            
     IF @b_debug = '1'            
     BEGIN            
      SELECT convert(nvarchar(3),@n_intFlag),* FROM #Result            
     END            
                             
             
    IF @b_debug='1'          
    BEGIN          
      SELECT 'chk', * from #Result          
    END   
  END                
              
  FETCH NEXT FROM CUR_RowNoLoop INTO @c_Getlabelno,@c_GetCartonNo,@c_GetExternORDKey               
              
      END -- While                       
      CLOSE CUR_RowNoLoop                      
      DEALLOCATE CUR_RowNoLoop                  
               
            
   FETCH NEXT FROM CUR_StartRecLoop INTO @c_ExternORDKey,@C_consigneeKey,@C_STCompany,@C_STState,@C_STCity,@c_STAdd1  
                                        ,@c_STAdd2,@c_STAdd3,@c_STAdd4,@c_STPhone1,@c_labelno,@c_cartonno,@c_CartonGID --WL01  
            
   END -- While                       
   CLOSE CUR_StartRecLoop                      
   DEALLOCATE CUR_StartRecLoop                
         
   SELECT * from #result WITH (NOLOCK)            
            
   EXIT_SP:              
            
   SET @d_Trace_EndTime = GETDATE()            
   SET @c_UserName = SUSER_SNAME()                                  
             
                                      
END -- procedure     

GO