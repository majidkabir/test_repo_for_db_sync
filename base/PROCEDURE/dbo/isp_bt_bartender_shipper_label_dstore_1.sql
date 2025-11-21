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
/* 2013-12-30 1.0  CSCHONG    Created                                         */               
/* 2014-01-23 2.0  CSCHONG    Change to cater for dynamic carton detail (CS01)*/               
/* 2014-05-13 2.1  SHONG      Fixing Problem                                  */       
/* 2014-05-14 2.2  CSCHONG    Group by sku style (CS02)                       */       
/* 2014-05-20 2.3  SHONG      Fixing Total Page Calculation issues (SHONG01)  */    
/* 2014-05-20 2.4  CSCHONG    Remove the space and add in TTL Qty (CS03)      */    
/* 2014-05-20 2.5  CSCHONG    For col13 (CS04)                                */    
/* 2014-06-03 2.6  CSCHONG    Exit if caseid is null (CS05)                   */    
/* 2014-06-13 2.4  CSCHONG    Fix total page = 1 , add new field and          */    
/*                            tote Consolidation (CS06)                       */    
/* 2017-02-27 2.5  CSCHONG    Remove SET ANSI_WARNINGS OFF (CS07)             */    
/* 2017-08-30 2.6  CSCHONG    Scripts tunning (CS08)                          */   
/* 2020-03-19 2.7  WLChooi    WMS-12525 - Modify Col02, Add Col37-40 (WL01)   */   
/* 2021-04-02 2.8  CSCHONG    WMS-16024 PB-Standardize TrackingNo (CS09)      */               
/******************************************************************************/                            
                              
CREATE PROC [dbo].[isp_BT_Bartender_Shipper_Label_DSTORE_1]                                   
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
   --SET ANSI_WARNINGS OFF                   --CS07                             
                                          
   DECLARE                
      @c_ToCompany       NVARCHAR(30),                            
      @C_ToAddress       NVARCHAR(200),              
      @C_ToState         NVARCHAR(45),              
      @C_ToZip           NVARCHAR(18),              
      @C_ToCity          NVARCHAR(45),              
      @C_ToCountry       NVARCHAR(30),              
      @c_FromCompany     NVARCHAR(30),                            
      @C_FromAddress     NVARCHAR(200),              
      @C_FromState       NVARCHAR(45),              
      @C_FromZip         NVARCHAR(18),              
      @C_FromCity        NVARCHAR(45),              
      @C_FromCountry     NVARCHAR(30),              
      @c_ToCompany1      NVARCHAR(30),                            
      @C_ToAddress1      NVARCHAR(200),              
      @C_ToState1        NVARCHAR(45),              
      @C_ToZip1          NVARCHAR(18),              
      @C_ToCity1         NVARCHAR(45),              
      @C_ToCountry1      NVARCHAR(30),              
      @c_FromCompany1    NVARCHAR(30),                            
      @C_FromAddress1    NVARCHAR(200),              
      @C_FromState1      NVARCHAR(45),              
      @C_FromZip1        NVARCHAR(18),              
      @C_FromCity1       NVARCHAR(45),              
      @C_FromCountry1    NVARCHAR(30),              
      @c_OrderKey        NVARCHAR(10),                                
      @c_ExternOrderKey  NVARCHAR(50),                          
      @c_Deliverydate    DATETIME,                          
      @c_caseid          NVARCHAR(20),               
      @c_ORDUDef10       NCHAR(2),              
      @c_ORDUDef04       NVARCHAR(20),        
      @c_ORDUDef04_1     NVARCHAR(20),              
      @c_wavekey         NVARCHAR(10),              
      @c_wavekey1        NVARCHAR(10),              
      @c_CaseID1         NVARCHAR(20),              
      @c_ODUDEF01        NVARCHAR(20),              
      @c_ODUDEF02        NVARCHAR(20),              
      @c_Carton          NVARCHAR(10),              
      @c_CodelShort      NVARCHAR(10),              
      @c_ODUDEF01_1      NVARCHAR(20),              
      @c_ODUDEF02_1      NVARCHAR(20),              
      @c_Carton1         NVARCHAR(10),              
      @c_CodelShort1     NVARCHAR(10),                
      @c_Style           NVARCHAR(20),               
      @n_intFlag         INT,                 
      @n_CntRec          INT,              
      @c_colNo           NVARCHAR(5),              
      @c_colContent01    NVARCHAR(80),               
      @c_colContent02    NVARCHAR(80),                
      @c_colContent03    NVARCHAR(80),              
      @c_colContent04    NVARCHAR(80),              
      @c_colContent05    NVARCHAR(80),              
      @c_colContent06    NVARCHAR(80),              
      @c_colContent07    NVARCHAR(80),              
      @c_colContent08    NVARCHAR(80),              
      @c_colContent09    NVARCHAR(80),              
      @c_colContent10    NVARCHAR(80),              
      @c_ColContent      NVARCHAR(80),              
      @n_cntsku          INT,              
      @c_skuMeasurement  NVARCHAR(5),              
      @c_Company         NVARCHAR(45),                          
      @C_Address1        NVARCHAR(45),                          
      @C_Address2        NVARCHAR(45),                          
      @C_Address3        NVARCHAR(45),                          
      @C_Address4        NVARCHAR(45),                          
      @C_BuyerPO         NVARCHAR(20),                          
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
      @n_SumUnitPrice    INT,                      
      @c_SQL             NVARCHAR(4000),                    
      @c_SQLSORT         NVARCHAR(4000),                    
      @c_SQLJOIN         NVARCHAR(4000),                  
      @c_Udef04          NVARCHAR(80),         --(CS04)                  
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
      @n_cntOrdUDef04    INT,              --(CS04)    
      @c_getOrdUdef04    NVARCHAR(80),      --(CS04)     
      @c_colContent11    NVARCHAR(80),     --(CS06)          
      @c_colContent12    NVARCHAR(80),     --(CS06)     
      @c_colContent13    NVARCHAR(80),     --(CS06)       
      @c_colContent14    NVARCHAR(80),     --(CS06)       
      @c_colContent15    NVARCHAR(80),     --(CS06)       
      @c_S1Address1      NVARCHAR(80),     --WL01  
      @c_S1Address2      NVARCHAR(80),     --WL01  
      @c_S1Address3      NVARCHAR(80),     --WL01  
      @c_S1Address4      NVARCHAR(80),     --WL01  
      @c_S1Address1_1    NVARCHAR(80),     --WL01  
      @c_S1Address2_1    NVARCHAR(80),     --WL01  
      @c_S1Address3_1    NVARCHAR(80),     --WL01  
      @c_S1Address4_1    NVARCHAR(80)      --WL01  
                
              
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
   SET @n_SumUnitPrice = 0                        
                          
--    IF OBJECT_ID('tempdb..#Result','u') IS NOT NULL            
--      DROP TABLE #Result;     
    
   IF ISNULL(@c_Sparm3,'') = ''    
   BEGIN    
      IF @b_debug = '1'    
      BEGIN    
         PRINT 'Caseid null'    
      END    
      RETURN;    
   END            
              
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
      [OrderKey]    [NVARCHAR] (10) NULL,                                        
      [DUdef10]     [NCHAR] (2) NULL,               
      [DUdef03]     [NCHAR] (2) NULL,                 
      [itemclass]   [NCHAR] (4) NULL,                
      [skugroup]    [NCHAR] (5) NULL,                 
      [style]       [NCHAR] (5) NULL,              
      [TTLPICKQTY]  [INT] NULL,              
      [Retrieve]    [NVARCHAR] (1) default 'N')                   
              
            
--      IF OBJECT_ID('tempdb..#PICK','u') IS NOT NULL            
--      DROP TABLE #PICK;            
            
   CREATE TABLE [#PICK] (                         
      [ID]          [INT] IDENTITY(1,1) NOT NULL,                                        
      [OrderKey]    [NVARCHAR] (80) NULL,                          
      [TTLPICKQTY]  [INT] NULL)                       
            
            
--      IF OBJECT_ID('tempdb..#SKU','u') IS NOT NULL            
--      DROP TABLE #SKU;            
            
   CREATE TABLE [#SKU] (                         
      [ID]          [INT] IDENTITY(1,1) NOT NULL,                                        
      [measurement] [NVARCHAR] (10) NULL)                   
       
    
   CREATE TABLE [#Order] (                       
      [ID]           [INT] IDENTITY(1,1) NOT NULL,                                      
      [userdefine04] [NVARCHAR] (80) NULL)                        
          
   IF @b_debug=1                    
   BEGIN                      
      PRINT 'start'                      
   END              
              
   DECLARE CUR_StartRecLoop CURSOR LOCAL FAST_FORWARD READ_ONLY FOR                        
   SELECT s1.company as ShipTo_Company,  
          SUBSTRING((LTRIM(RTRIM(ISNULL(s1.Address1,''))) + LTRIM(RTRIM(ISNULL(s1.Address2,''))) +   
          LTRIM(RTRIM(ISNULL(s1.Address3,''))) + LTRIM(RTRIM(ISNULL(s1.Address4,''))) ),1,80) as shipTo_Address,  --WL01          
          s1.state as ShipTo_State,s1.city as ShipTo_City,s1.zip as ShipTo_Zip ,s1.country as ShipTo_Country,            
          s2.company as ShipFrom_Company,ISNULL((s2.address1+s2.address2+s2.address3+s2.address4),'') as shipFrom_address,            
          s2.state as ShipFrom_State,ISNULL(s2.city,'') as ShipFrom_City, ISNULL(s2.zip,'') as ShipFrom_Zip,            
          ISNULL(s2.country,'') as ShipFrom_Country,'',WD.wavekey,pd.caseid,            
          MAX(ISNULL(od.userdefine01,'')) as DUDef01,replace(max(od.userdefine02),'ANF','') as DUdef02,            
          substring(pd.caseID,7,5),CP.Short,  
          LTRIM(RTRIM(ISNULL(s1.Address1,''))), LTRIM(RTRIM(ISNULL(s1.Address2,''))),   --WL01  
          LTRIM(RTRIM(ISNULL(s1.Address3,''))), LTRIM(RTRIM(ISNULL(s1.Address4,'')))    --WL01  
   FROM ORDERS ORD  WITH (NOLOCK) INNER JOIN ORDERDETAIL od WITH (NOLOCK) ON od.orderkey=ORD.orderkey                 
   LEFT JOIN STORER s1 WITH (NOLOCK) ON s1.storerkey = od.userdefine02                
   LEFT JOIN STORER s2 WITH (NOLOCK) ON s2.storerkey = ORD.facility               
   LEFT JOIN Wavedetail WD WITH (NOLOCK) ON WD.Orderkey = ORD.Orderkey                
   LEFT JOIN SKU s WITH (NOLOCK) ON s.sku=od.sku AND s.StorerKey = od.StorerKey                 
   JOIN pickdetail pd WITH (NOLOCK) ON pd.orderkey=ORD.orderkey                
               AND pd.OrderLineNumber = od.OrderLineNumber               
   LEFT JOIN PACKHEADER PH WITH (NOLOCK) ON PH.loadkey = ORD.loadkey            
   LEFT JOIN PACKDETAIL PDET WITH (NOLOCK) ON PDET.Pickslipno = PH.Pickslipno --AND od.sku=od.sku            
   JOIN CODELKUP CP WITH (NOLOCK) ON CP.CODE=ORD.Facility    
     --WHERE ORD.LoadKey =  CASE WHEN ISNULL(RTRIM(@c_Sparm1),'') <> '' THEN @c_Sparm1 ELSE ORD.LoadKey END --@c_Sparm1        --(CS06)    
   WHERE (ISNULL(RTRIM(@c_Sparm1),'') = '' OR ORD.LoadKey = RTRIM(@c_Sparm1))                                                --(CS08)  
   AND CP.listname='ANFFAC'           
    --AND ORD.OrderKey = CASE WHEN ISNULL(RTRIM(@c_Sparm2),'') <> '' THEN @c_Sparm2 ELSE ORD.OrderKey END      
   AND   (ISNULL(RTRIM(@c_Sparm2),'') = '' OR ORD.OrderKey = RTRIM(@c_Sparm2))       
   AND pd.caseid = @c_Sparm3            
   -- AND ORD.type = CASE WHEN ISNULL(RTRIM(@c_Sparm4),'') <> '' THEN @c_Sparm4 ELSE ORD.type END     
   AND   (ISNULL(RTRIM(@c_Sparm4),'') = '' OR ORD.type = RTRIM(@c_Sparm4))        
   -- AND PDET.Dropid = CASE WHEN ISNULL(RTRIM(@c_Sparm5),'') <> '' THEN @c_Sparm5 ELSE PDET.Dropid END        
   AND   (ISNULL(RTRIM(@c_Sparm5),'') = '' OR PDET.Dropid = RTRIM(@c_Sparm5))                   
   group by s1.company,  
   SUBSTRING((LTRIM(RTRIM(ISNULL(s1.Address1,''))) + LTRIM(RTRIM(ISNULL(s1.Address2,''))) +   
   LTRIM(RTRIM(ISNULL(s1.Address3,''))) + LTRIM(RTRIM(ISNULL(s1.Address4,''))) ),1,80),  --WL01    
   s1.state,s1.city,              
   s1.zip ,s1.country, s2.company,(s2.address1+s2.address2+s2.address3+s2.address4),s2.state,              
   s2.city ,s2.zip ,s2.country,WD.wavekey,pd.caseid,substring(pd.caseID,7,5),              
   CP.Short,  
   LTRIM(RTRIM(ISNULL(s1.Address1,''))), LTRIM(RTRIM(ISNULL(s1.Address2,''))),   --WL01  
   LTRIM(RTRIM(ISNULL(s1.Address3,''))), LTRIM(RTRIM(ISNULL(s1.Address4,'')))    --WL01              
              
   OPEN CUR_StartRecLoop                        
                   
   FETCH NEXT FROM CUR_StartRecLoop INTO @c_ToCompany,@C_ToAddress,@C_ToState,@C_ToCity,@C_ToZip,@C_ToCountry,@c_FromCompany,              
                                         @C_FromAddress,@C_FromState,@C_FromCity,@C_FromZip,@C_FromCountry,@c_ORDUDef04,              
                                         @c_wavekey,@c_CaseID,@c_ODUDEF01,@c_ODUDEF02,@c_Carton,@c_CodelShort,  
                                         @c_S1Address1, @c_S1Address2 ,@c_S1Address3, @c_S1Address4          --WL01         
                     
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
      VALUES(@c_ToCompany,@C_ToAddress,@C_ToState,@C_ToCity,@C_ToZip,@C_ToCountry,@c_FromCompany,              
             @C_FromAddress,@C_FromState,@C_FromCity,@C_FromZip,@C_FromCountry,'',              
             '',@c_wavekey,@c_CaseID,@c_ODUDEF01,@c_ODUDEF02,@c_Carton,@c_CodelShort,     --20          
             '','','','','','','','','','','','','','','','',@c_S1Address1, @c_S1Address2, @c_S1Address3, @c_S1Address4, --40  
             '','','','','','','','','','',              
             '','','','','','','','','','O')              
              
              
      IF @b_debug=1                    
      BEGIN                    
         SELECT * FROM #Result (nolock)                    
      END               
                 
      SET @n_MaxLine = 15              
      SET @n_TTLpage = 1               
      SET @n_CurrentPage = 1              
      SET @n_intFlag = 1              
      SET @n_TTLLIne = 0              
      SET @n_TTLQty = 0              
                
      DECLARE CUR_RowNoLoop CURSOR LOCAL FAST_FORWARD READ_ONLY FOR                          
                            
      SELECT DISTINCT col01,col02,col03,col04,col05,col06,col07,col08,col09,Col10,              
                      col11,col12,col13,col15,col16,col17,col18,col19,Col20,  
                      col37, col38, col39, col40      --WL01        
      FROM #Result                     
      WHERE Col60 = 'O'               
                   
      OPEN CUR_RowNoLoop                        
                   
      FETCH NEXT FROM CUR_RowNoLoop INTO @c_ToCompany1,@C_ToAddress1,@C_ToState1,@C_ToCity1,@C_ToZip1,@C_ToCountry1,@c_FromCompany1,              
                                         @C_FromAddress1,@C_FromState1,@C_FromCity1,@C_FromZip1,@C_FromCountry1,@c_ORDUDef04_1,              
                                         @c_wavekey1,@c_CaseID1,@c_ODUDEF01_1,@c_ODUDEF02_1,@c_Carton1,@c_CodelShort1,  
                                         @c_S1Address1_1, @c_S1Address2_1 ,@c_S1Address3_1, @c_S1Address4_1          --WL01                 
                     
      WHILE @@FETCH_STATUS <> -1                   
      BEGIN                       
         IF @b_debug='1'                    
         BEGIN                    
            PRINT 'CASE ID= ' + @c_caseid                       
         END                    
                       
         --SET @n_intFlag = 1              
                     
         INSERT INTO #CartonContent (DUdef10,DUdef03,ItemClass,SkuGroup,style,TTLPICKQTY)              
--         SELECT ISNULL(o.userdefine10 ,'')          
--               ,ISNULL(o.userdefine03 ,'')          
--               ,s.itemclass          
--               ,s.skugroup          
--               ,ISNULL(s.style ,'')          
--               ,SUM(pd.qty)          
--         FROM orders o WITH (NOLOCK)       
--         JOIN pickdetail pd WITH (NOLOCK)          
--                     ON  pd.orderkey = o.orderkey          
--    JOIN sku s WITH (NOLOCK)  ON  s.sku = pd.sku          
--                                   AND s.StorerKey = pd.Storerkey          
--         WHERE  pd.caseid = @c_caseid1          
--         AND    pd.orderkey = CASE           
--                                   WHEN @c_Sparm2 <> '' THEN @c_Sparm2          
--                                   ELSE pd.orderkey          
--                              END          
--         GROUP BY          
--               ISNULL(o.userdefine10 ,'')          
--              ,ISNULL(o.userdefine03 ,'')          
--              ,s.itemclass          
--              ,s.skugroup          
--              ,s.style      
         SELECT --pd.orderkey        --(CS02)    
             ISNULL(o.userdefine10 ,'')        
            ,ISNULL(o.userdefine03 ,'')        
            ,s.itemclass        
            ,s.skugroup        
            ,ISNULL(s.style ,'')        
            ,SUM(pd.qty)        
         FROM   orders o WITH (NOLOCK) --JOIN ORDERDETAIL od WITH (NOLOCK)        
                      --on od.orderkey=o.orderkey        
         JOIN pickdetail pd WITH (NOLOCK)        
                  ON  pd.orderkey = o.orderkey        
         JOIN sku s WITH (NOLOCK)        
                  ON  s.sku = pd.sku        
         AND    s.StorerKey = pd.Storerkey        
         WHERE  pd.caseid = @c_caseid1        
         AND    pd.orderkey = CASE WHEN @c_Sparm2 <> '' THEN @c_Sparm2        
                               ELSE pd.orderkey END        
         GROUP BY        
            -- pd.orderkey    --(CS02)    
             ISNULL(o.userdefine10 ,'')        
            ,ISNULL(o.userdefine03 ,'')        
            ,s.itemclass        
            ,s.skugroup        
            ,s.style            
                                  
         IF @b_debug = '1'                  
         BEGIN                  
            SELECT 'carton',* FROM #CartonContent         
         END                  
                
         SET @c_colno=''              
                   
         SET @c_colContent01 = ''              
         SET @c_colContent02 = ''              
         SET @c_colContent03 = ''              
         SET @c_colContent04 = ''              
         SET @c_colContent05 = ''              
         SET @c_colContent06 = ''              
         SET @c_colContent07 = ''              
         SET @c_colContent08 = ''              
         SET @c_colContent09 = ''              
         SET @c_colContent10 = ''     
         SET @c_colContent11 = ''  --(CS06)           
         SET @c_colContent12 = ''  --(CS06)          
         SET @c_colContent13 = ''  --(CS06)          
         SET @c_colContent14 = ''  --(CS06)          
         SET @c_colContent15 = ''  --(CS06)                  
                    
         SELECT @n_CntRec = count(1)               
         FROM #CartonContent                       
         WHERE Retrieve = 'N'              
                 
         --SET @n_TTLpage = round((@n_CntRec/@n_MaxLine),1) + 1        
         -- Fixed by SHONG (SHONG01)            
         SET @n_TTLpage =  FLOOR(@n_CntRec / @n_MaxLine ) + CASE WHEN @n_CntRec % @n_MaxLine > 0 THEN 1 ELSE 0 END      
                  
         IF @b_debug='1'              
         BEGIN              
            PRINT ' Rec Count : ' + convert(nvarchar(15),@n_CntRec)              
            PRINT ' TTL Page NO : ' + convert(nvarchar(15),@n_TTLpage)              
            PRINT ' Current Page NO : ' + convert(nvarchar(15),@n_CurrentPage)              
         END              
              
         WHILE (@n_intFlag <=@n_MaxLine)              
         BEGIN              
            IF @b_debug = '1'                  
            BEGIN                 
               SELECT * FROM  #CartonContent  WITH (NOLOCK)                
               PRINT ' update for column no : ' + @c_Colno + 'with ID ' + convert(nvarchar(2),@n_intFlag)              
            END                  
           /*CS06 start */    
          /*  IF @n_intFlag = 11 OR @n_intFlag = 21 OR @n_intFlag = 31 OR @n_intFlag = 41 OR @n_intFlag = 51              
            BEGIN                            
              SET @n_CurrentPage = @n_CurrentPage + 1              
              PRINT 'Start page : ' + convert(nvarchar(5),@n_CurrentPage)         
                  
              WHILE (@n_CurrentPage>@n_TTLpage)              
                 BREAK;              
                   
              INSERT INTO #Result (Col01,Col02,Col03,Col04,Col05, Col06,Col07,Col08,Col09                       
                                 ,Col10,Col11,Col12,Col13,Col14,Col15,Col16,Col17,Col18,Col19,Col20,Col21,Col22                     
                                 ,Col23,Col24,Col25,Col26,Col27,Col28,Col29,Col30,Col31,Col32,Col33,Col34                      
                                 ,Col35,Col36,Col37,Col38,Col39,Col40,Col41,Col42,Col43,Col44                       
                                 ,Col45,Col46,Col47,Col48,Col49,Col50,Col51,Col52,Col53,Col54                     
                                 ,Col55,Col56,Col57,Col58,Col59,Col60)              
              VALUES(@c_ToCompany1,@C_ToAddress1,@C_ToState1,@C_ToCity1,@C_ToZip1,@C_ToCountry1,@c_FromCompany1,              
                 @C_FromAddress1,@C_FromState1,@C_FromCity1,@C_FromZip1,@C_FromCountry1,'',              
                 '',@c_wavekey1,@c_CaseID1,@c_ODUDEF01_1,@c_ODUDEF02_1,@c_Carton1,@c_CodelShort1,                
                 '','','','','','','','','','','','','','','','','','','','','','','','','','','','','','',              
                 '','','','','','','','','','N')              
                          
                SET @c_colContent01 = ''              
                SET @c_colContent02 = ''              
                SET @c_colContent03 = ''              
                SET @c_colContent04 = ''              
                SET @c_colContent05 = ''              
                SET @c_colContent06 = ''              
                SET @c_colContent07 = ''              
                SET @c_colContent08 = ''              
                SET @c_colContent09 = ''              
                SET @c_colContent10 = ''              
                      
            END              
          */    
         /*CS06 end */    
            SET @c_Colcontent = ''              
            SET @n_TTLLine = 0              
            SET @n_Qty = 0              
                     
--            SELECT @c_Colcontent = case when DUdef10 = '' then space(4) ELSE cast(DUdef10 as nchar(2)) + space(2) END            
--                                + case when DUdef03 = '' then space(4) ELSE cast(DUdef03 as nchar(2)) + space(2) END            
--                                + cast(itemclass as nchar(4)) + space(2)             
--                                + cast(skugroup as nchar(5)) + space(2)             
--                                + case when style = '' then space(11) ELSE cast(style as nchar(5)) + space(2) END          
--                                + convert(nchar(5),TTLPICKQTY)     
           -- SELECT @c_Colcontent = DUdef10 + space(2) + DUdef03 + space(2) + itemclass + space(2) + skugroup + space(2) + style + space(2) +     
            SELECT @c_Colcontent = DUdef10 + DUdef03 + itemclass + skugroup +  style +  convert(nvarchar(5),TTLPICKQTY)               
            FROM  #CartonContent c WITH (NOLOCK)                          
            WHERE c.ID = @n_intFlag              
            
              
            IF @b_debug='1'              
            BEGIN             
               PRINT 'check 1 ' +  substring(@c_Colcontent,1,4)            
               PRINT 'check 2 ' +  substring(@c_Colcontent,5,4)            
               PRINT 'check 3 ' +  substring(@c_Colcontent,9,6)            
               PRINT 'check 4 ' +  substring(@c_Colcontent,15,7)            
               PRINT 'check 5 ' +  substring(@c_Colcontent,22,7)            
               PRINT 'check 6 ' +  right(@c_Colcontent,5)            
               PRINT 'Udef10 : ' +  @c_OrdUdef10 + '03: ' + @c_OrdUdef03+ ' class ' + @c_itemclass + 'grp : ' + @c_skuGrp+ 'style:' +@c_SkuStyle+ 'qty : ' + convert(nchar(5),@n_TTLPickQTY)            
               PRINT 'Content : ' + @c_Colcontent + 'with lenght : ' + convert(nvarchar(3),LEN(@c_Colcontent))              
               --PRINT ' len(U10) : +             
            END              
              
            --IF @n_intFlag = 1 or @n_intFlag = 11 or @n_intFlag = 21 or @n_intFlag = 31     
            IF (@n_intFlag%@n_MaxLine) = 1              
            BEGIN              
               SET @c_colContent01 = @c_Colcontent              
            END                          
            --ELSE IF @n_intFlag = 2 OR @n_intFlag = 12 OR @n_intFlag = 22 OR @n_intFlag = 32              
            ELSE IF (@n_intFlag%@n_MaxLine) = 2    
            BEGIN              
               SET @c_colContent02 = @c_Colcontent              
            END      
                        
            --ELSE IF @n_intFlag = 3 OR @n_intFlag = 13 OR @n_intFlag = 23              
            ELSE IF (@n_intFlag%@n_MaxLine) = 3    
            BEGIN                
               SET @c_colContent03 = @c_Colcontent              
            END     
                         
            --ELSE IF @n_intFlag = 4 OR @n_intFlag = 14 OR @n_intFlag = 24              
            ELSE IF (@n_intFlag%@n_MaxLine) = 4    
            BEGIN              
               SET @c_colContent04 = @c_Colcontent              
            END    
                    
            --ELSE IF @n_intFlag = 5 OR @n_intFlag = 15 OR @n_intFlag = 25              
            ELSE IF (@n_intFlag%@n_MaxLine) = 5    
            BEGIN              
               SET @c_colContent05 = @c_Colcontent              
            END    
                    
            --ELSE IF @n_intFlag = 6 OR @n_intFlag = 16 OR @n_intFlag = 26              
            ELSE IF (@n_intFlag%@n_MaxLine) = 6    
            BEGIN              
               SET @c_colContent06 = @c_Colcontent              
            END                           
            --ELSE IF @n_intFlag = 7 OR @n_intFlag = 17 OR @n_intFlag = 27              
            ELSE IF (@n_intFlag%@n_MaxLine) = 7    
            BEGIN              
               SET @c_colContent07 = @c_Colcontent              
            END                    
            --ELSE IF @n_intFlag = 8 OR @n_intFlag = 18 OR @n_intFlag = 28              
            ELSE IF (@n_intFlag%@n_MaxLine) = 8    
            BEGIN              
               SET @c_colContent08 = @c_Colcontent              
            END                    
            --ELSE IF @n_intFlag = 9 OR @n_intFlag = 19 OR @n_intFlag = 29              
            ELSE IF (@n_intFlag%@n_MaxLine) = 9    
            BEGIN              
               SET @c_colContent09 = @c_Colcontent              
            END              
            --ELSE IF @n_intFlag = 10 OR @n_intFlag = 20 OR @n_intFlag = 30              
            ELSE IF (@n_intFlag%@n_MaxLine) = 10    
            BEGIN              
               SET @c_colContent10 = @c_Colcontent              
            END     
               
            ELSE IF (@n_intFlag%@n_MaxLine) = 11    
            BEGIN              
               SET @c_colContent11 = @c_Colcontent              
            END      
    
            ELSE IF (@n_intFlag%@n_MaxLine) = 12    
            BEGIN              
               SET @c_colContent12 = @c_Colcontent              
            END      
    
            ELSE IF (@n_intFlag%@n_MaxLine) = 13    
            BEGIN              
               SET @c_colContent13 = @c_Colcontent              
            END      
              
            ELSE IF (@n_intFlag%@n_MaxLine) = 14    
            BEGIN              
               SET @c_colContent14 = @c_Colcontent              
            END      
             
            ELSE IF (@n_intFlag%@n_MaxLine) = 0    
            BEGIN              
            SET @c_colContent15 = @c_Colcontent              
            END        
           /*CS03 start*/    
    
            SET @n_TTLQty = 0    
    
            SELECT @n_TTLQty = SUM(TTLPICKQTY)    
            FROM  #CartonContent c WITH (NOLOCK)                            
                     
            IF @b_debug = '1'                  
            BEGIN                  
               PRINT ' update for column content1 : ' + @c_ColContent01              
               PRINT ' update for column content2 : ' + @c_ColContent02              
               PRINT ' update for column content3 : ' + @c_ColContent03              
               PRINT ' update for column content9: ' + @c_ColContent09              
               PRINT ' update for column content10 : ' + @c_ColContent10              
            END                 
                    
            UPDATE #Result                        
            SET Col21 = convert(nvarchar(10),@n_TTLQty),               
                Col22 = @c_ColContent01,              
                Col23 = @c_ColContent02,                    
                Col24 = @c_ColContent03,               
                Col25 = @c_ColContent04,               
                Col26 = @c_ColContent05,              
                Col27 = @c_ColContent06,              
                Col28 = @c_ColContent07,              
                Col29 = @c_ColContent08,              
                Col30 = @c_ColContent09,     
                Col31 = @c_ColContent10,    
                Col32 = @c_ColContent11,            
                Col33 = @c_ColContent12,                    
                Col34 = @c_ColContent13,             
                Col35 = @c_ColContent14,    
                Col36 = @c_ColContent15             
            WHERE ID = @n_CurrentPage                
              /*CS03 End*/                    
            --SET @n_intFlag = @n_intFlag + 1              
              
            IF @b_debug = '1'              
            BEGIN              
             SELECT convert(nvarchar(3),@n_intFlag),* FROM #Result              
            END              
                      
            SET @n_cntsku = 0            
            INSERT INTO #SKU (measurement)                           
            SELECT CASE s.Measurement WHEN 'F' THEN 'W'ELSE s.Measurement  END            
            FROM packdetail pd WITH (NOLOCK)               
            JOIN SKU s WITH (NOLOCK) ON S.sku=pd.sku and s.StorerKey = pd.StorerKey              
            WHERE pd.labelno=@c_caseid              
            GROUP BY pd.cartonno,s.Measurement               
                     
            SELECT @n_cntsku= count (distinct Measurement)            
                 , @c_skuMeasurement = CASE Measurement WHEN 'F' THEN 'W'ELSE Measurement  END            
            FROM #SKU            
            GROUP BY Measurement     
    
            /*CS04 start*/    
              
            SET @n_cntOrdUdef04 = 0          
            INSERT INTO #Order (userdefine04)          
            SELECT DISTINCT ORD.trackingno             --CS09  
            FROM pickdetail PD WITH (nolock)    
            JOIN orders ORD WITH (nolock) on ord.orderkey=pd.orderkey    
            WHERE caseid=@c_caseid          
                  
            SELECT @n_cntOrdUdef04= count (distinct userdefine04)          
               -- , @c_getOrdUdef04 = userdefine04          
            FROM #Order          
            -- GROUP BY userdefine04      
            /*Cs04 End*/           
            
            IF @b_debug='1'            
            BEGIN            
              SELECT 'sku', * from #SKU      
              SELECT 'Userdefine04', * from #Order           
            END     
    
            /*CS04 Start*/       
            IF @n_cntOrdUdef04 = 1             
            BEGIN          
               SELECT TOP 1 @c_getOrdUdef04 = userdefine04    
               FROM #Order     
              
               UPDATE #Result                      
             SET Col13= @c_getOrdUdef04            
               WHERE ID = @n_CurrentPage       
                 
            END            
            ELSE            
            BEGIN            
               UPDATE #Result                      
               SET Col13 = ''            
               WHERE ID = @n_CurrentPage            
            END          
            /*CS04 END*/           
              
            IF @n_cntsku = 1               
            BEGIN              
               UPDATE #Result                        
               SET Col14= @c_skuMeasurement              
               WHERE ID = @n_CurrentPage              
            END              
            ELSE              
            BEGIN              
               UPDATE #Result                        
               SET Col14 = 'mixed'              
               WHERE ID = @n_CurrentPage              
            END              
               
            IF @b_debug='1'            
            BEGIN            
               SELECT 'chk', * from #Result            
            END            
                   
            SET @n_intFlag = @n_intFlag + 1                       
         END                  
                
         FETCH NEXT FROM CUR_RowNoLoop INTO @c_ToCompany1,@C_ToAddress1,@C_ToState1,@C_ToCity1,@C_ToZip1,@C_ToCountry1,@c_FromCompany1,              
                                            @C_FromAddress1,@C_FromState1,@C_FromCity1,@C_FromZip1,@C_FromCountry1,@c_ORDUDef04_1,              
                                            @c_wavekey1,@c_CaseID1,@c_ODUDEF01_1,@c_ODUDEF02_1,@c_Carton1,@c_CodelShort1,  
                                            @c_S1Address1_1, @c_S1Address2_1 ,@c_S1Address3_1, @c_S1Address4_1          --WL01                          
                
      END -- While                         
      CLOSE CUR_RowNoLoop                        
      DEALLOCATE CUR_RowNoLoop                    
                 
              
      FETCH NEXT FROM CUR_StartRecLoop INTO @c_ToCompany,@C_ToAddress,@C_ToState,@C_ToCity,@C_ToZip,@C_ToCountry,@c_FromCompany,              
                                            @C_FromAddress,@C_FromState,@C_FromCity,@C_FromZip,@C_FromCountry,@c_ORDUDef04,              
                                            @c_wavekey,@c_CaseID,@c_ODUDEF01,@c_ODUDEF02,@c_Carton,@c_CodelShort,  
                                            @c_S1Address1, @c_S1Address2 ,@c_S1Address3, @c_S1Address4          --WL01                             
              
   END -- While                         
   CLOSE CUR_StartRecLoop                        
   DEALLOCATE CUR_StartRecLoop                
         
   -- (SHONG01)              
   SELECT * FROM #result       
   WHERE LEN(ISNULL(Col21,'') +  ISNULL(Col22,'') + ISNULL(Col23,'') +                      
         ISNULL(Col24,'') +  ISNULL(Col25,'') + ISNULL(Col26,'') +              
         ISNULL(Col27,'') +  ISNULL(Col28,'') +  ISNULL(Col29,'') +              
         ISNULL(Col30,'')) > 0          
              
   EXIT_SP:                
              
   SET @d_Trace_EndTime = GETDATE()              
   SET @c_UserName = SUSER_SNAME()              
                 
   EXEC isp_InsertTraceInfo               
      @c_TraceCode = 'BARTENDER',              
      @c_TraceName = 'isp_BT_Bartender_Shipper_Label_DSTORE_1',              
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