SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store Procedure: isp_Print_UCC_CartonLabel_57                        */  
/* Creation Date: 07-Apr-2017                                           */  
/* Copyright: IDS                                                       */  
/* Written by: CSCHONG                                                  */  
/*                                                                      */  
/* Purpose: WMS-1415 - CN&SG Logitech Carton Label                      */  
/*                                                                      */  
/* Input Parameters: @cStorerKey - StorerKey,                           */  
/*                   @cPickSlipNo - Pickslipno,                         */  
/*                   @cFromCartonNo - From CartonNo,                    */  
/*                   @cToCartonNo - To CartonNo,                        */  
/*                                                                      */  
/*                                                                      */  
/* Usage: Call by dw = r_dw_ucc_carton_label_57                         */  
/*                                                                      */  
/* PVCS Version: 1.1 (Unicode)                                          */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author        Purposes                                  */  
/* 11-May-2017  CSCHONG       WMS-1415 - add new field (CS01)           */  
/* 17-May-2017  CSCHONG       WMS-1415 - Change field logic (CS02)      */  
/* 17-Jan-2018  CSCHONG       WMS-3769 - revised field mapping (CS03)   */  
/* 28-Jan-2019  TLTING_ext 1.1  enlarge externorderkey field length     */  
/* 21-MAY-2019  CSCHONG       WMS-8975 - Add new field (CS04)           */   
/* 29-Nov-2019  WLChooi       WMS-11254 - New layout based on           */  
/*                            storer.notes2 (WL01)                      */  
/* 18-Jan-2021  Shong         Adding Log into TraceInfo                 */  
/* 29-Nov-2022  mingle        WMS-19623 Add logic(ML01)                 */  
/************************************************************************/  
CREATE PROC [dbo].[isp_Print_UCC_CartonLabel_57] (   
   @cStorerKey    NVARCHAR( 15),  
   @cPickSlipNo   NVARCHAR( 10),   
   @cFromCartonNo NVARCHAR( 10),  
   @cToCartonNo   NVARCHAR( 10),   
   @cType         NVARCHAR( 10) = '' )  --WL01  
  -- @cFilePath     NVARCHAR( 100) )  
AS  
BEGIN  
   SET NOCOUNT ON   
   SET ANSI_NULLS OFF   
   SET QUOTED_IDENTIFIER OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE  
      @b_debug int  
  
   DECLARE   
      @nFromCartonNo         int,  
      @nToCartonNo           int,  
      @c_GetPickslipno       NVARCHAR( 10),  
      @c_sku                 NVARCHAR(20),  
      @c_Externorderkey      NVARCHAR(50),   --tlting_ext  
      @c_packkey             NVARCHAR(20),  
      @n_Casecnt             INT,  
      @n_GetPQty             INT,  
      @n_PQty                INT,  
      @n_GetTTLQty           INT,  
      @n_TTLQty              INT,  
      @n_getctnno            INT,  
      @n_getCtnCount         INT,  
      @n_startCtn            INT,  
      @c_presku              NVARCHAR(20),             --CS02  
      @n_cntsku              INT,                      --CS03  
      @c_facility            NVARCHAR(10),             --CS04    
      @c_consigneekey        NVARCHAR(45),             --CS04    
      @c_getcontact1         NVARCHAR(1),              --CS04    
  --START ML01  
  @n_MaxLine         INT,        
  @n_CntRec          INT,      
  @n_ReqLine         INT,      
  @c_showsample      NVARCHAR(5),      
  @QTY INT,      
  @n_qty INT,    
  @c_notes2      NVARCHAR(250),      
  @c_type        NVARCHAR(10),     
  @c_clcode      NVARCHAR(15),    
  @c_consignkey  NVARCHAR(15)   
  --END ML01  
     
   DECLARE   
      @d_Trace_StartTime     DATETIME,   
      @d_Trace_EndTime       DATETIME,     
      @c_UserName            NVARCHAR(128),   
      @c_ResultRowCtn        varchar(20)              
            
   SET @b_debug = 0  
   SET @n_startCtn = 1                                 --CS02  
   SET @c_presku = ''                                  --CS02  
   SET @c_getcontact1 = 'Y'                            --CS04    
   SET @d_Trace_StartTime = getdate()   
   SET @c_UserName = suser_sname()   
   SET @c_ResultRowCtn = '0'  
   SET @n_cntsku = 1  
	SET @n_MaxLine = 2 --ML01      
   SET @n_CntRec   = 1 --ML01        
   --SET @n_LastPage = 0        
   SET @n_ReqLine  = 1 --ML01  
  
   SET @nFromCartonNo = CAST( @cFromCartonNo AS int)  
   SET @nToCartonNo = CAST( @cToCartonNo AS int)  
  
   --WL01 Start  
   IF @cType = '4X6'  
   BEGIN   
      GOTO LABELWITHSKU  
   END  
   ELSE IF @cType = 'H'  
   BEGIN  
      SELECT TOP 1 @cStorerKey      
                 , @cPickSlipNo    
                 , @cFromCartonNo  
                 , @cToCartonNo    
                 , ISNULL(ST.Notes2,'') AS Notes2   
      FROM PACKHEADER PH (NOLOCK)  
      JOIN PACKDETAIL PD (NOLOCK) ON PD.Pickslipno = PH.Pickslipno  
      JOIN ORDERS OH (NOLOCK) ON OH.ORDERKEY = PH.ORDERKEY  
      LEFT JOIN STORER ST (NOLOCK) ON ST.STORERKEY = OH.CONSIGNEEKEY AND ST.[TYPE] = '2'  
      WHERE PH.Storerkey  =  @cStorerKey  
      AND PH.PickSlipNo =  @cPickSlipNo  
      AND PD.CartonNo BETWEEN CAST(@cFromCartonNo as INT) AND CAST(@cToCartonNo as INT)  
        
      SET @c_ResultRowCtn = CAST(@@ROWCOUNT AS VARCHAR(10))   
  
      GOTO QUIT_SP  
   END  
   --WL01 End  
  
  --START ML01
 CREATE TABLE #TEMPUCCLBL57_1 (      
   Pickslipno     NVARCHAR(10),      
   Labelno        NVARCHAR(20),      
   ExternOrdKey   NVARCHAR(20) NULL,      
   ExtenPOKey     NVARCHAR(20) NULL,      
   Storerkey      NVARCHAR(45) NULL,      
   CCompany      NVARCHAR(45) NULL,      
   CAddress      NVARCHAR(250) NULL,      
   CCityState    NVARCHAR(100) NULL,      
   CCountry      NVARCHAR(20) NULL,      
   ORDGrp        NVARCHAR(20) NULL,               
   SKU           NVARCHAR(20),      
   HFlag         NVARCHAR(5),      
   PQty          NVARCHAR(10),      
   TTLQty        NVARCHAR(10),      
   Orderkey   NVARCHAR(10),      
   BoxNo         NVARCHAR(50) NULL,      
   OHRoute       NVARCHAR(20) NULL,                
   CContact1     NVARCHAR(50) NULL,      
   ShowSample    NVARCHAR(5)      
   ) 
	--END ML01
     
   CREATE TABLE #TEMPUCCLBL57 (  
   Rowid         INT IDENTITY (1,1) NOT NULL,  --CS02  
   Storerkey     NVARCHAR(20),  
   OrderKey      NVARCHAR(10),  
   ExternOrdKey  NVARCHAR(20) NULL,  
   ExtenPOKey    NVARCHAR(20) NULL,  
   CCompany      NVARCHAR(45) NULL,  
   CAddress      NVARCHAR(250) NULL,  
   CCityState    NVARCHAR(100) NULL,  
   CCountry      NVARCHAR(20) NULL,  
   ORDGrp        NVARCHAR(20) NULL,         --CS02  
   Pickslipno    NVARCHAR(10),  
   labelno       NVARCHAR(20) NULL,  
   SKU           NVARCHAR(20),  
   HFlag         NVARCHAR(5),  
   PQty          NVARCHAR(10),  
   TTLQty        NVARCHAR(10),  
   BoxNo         NVARCHAR(50) NULL,  
   OHRoute       NVARCHAR(20) NULL,          --CS01  
   CtnNo         INT,                        --CS01  
   Ctncount      INT,                        --CS02  
   CContact1     NVARCHAR(50) NULL,          --CS04    
	ShowSample    NVARCHAR(5) NULL,    
   Notes2        NVARCHAR(250) NULL,    
   Type    NVARCHAR(10),    
   clcode        NVARCHAR(15),    
   consigneekey  NVARCHAR(15)  
   )  
  
   INSERT INTO #TEMPUCCLBL57  
   (     
    Storerkey,  
    OrderKey,  
    ExternOrdKey,  
    ExtenPOKey,  
    CCompany,  
    CAddress,  
    CCityState,  
    CCountry,  
    ORDGrp,                    --CS02  
    Pickslipno,  
    labelno,  
    SKU,  
    HFlag,  
    PQty,  
    TTLQty,  
    BoxNo,  
    OHRoute,   --CS01  
    CtnNo ,  
    Ctncount,                   --CS02       
    CContact1,                   --CS04   
	 ShowSample,    
	 Notes2,    
	 Type,        
	 clcode,           
	 consigneekey   
       )  
  
     
   SELECT ORDERS.storerkey,ORDERS.orderkey,   
          RTRIM(ORDERS.ExternOrderKey),ORDERS.ExternPOKey,  
          ORDERS.C_Company,  
          cAddress  = (ISNULL(RTRIM(ORDERS.C_Address1),'') + ' ' +ISNULL(RTRIM(ORDERS.C_Address2),'')   
                      + ' ' + ISNULL(RTRIM(ORDERS.C_Address3),'') + ' ' + ISNULL(RTRIM(ORDERS.C_Address4),'')),  
          ccitystate=( ISNULL(RTRIM(ORDERS.C_City),'') + ' ' + ISNULL(RTRIM(ORDERS.C_state),'') + ' ' + ISNULL(RTRIM(ORDERS.C_Zip),'')) ,  
          ORDERS.C_Country,ORDERS.OrderGroup,            --CS02  
          PACKHEADER.PickSlipNo,PACKDETAIL.LabelNo,   
       PACKDETAIL.SKU,SKU.HazardousFlag,  
       0,0,'',ORDERS.Route,                         --CS01  
       PACKDETAIL.CartonNo,  
       sum(PACKDETAIL.qty) over (partition by PACKDETAIL.sku order by PACKDETAIL.adddate) / p.casecnt,  
       ORDERS.c_contact1,  
   ISNULL(CL.SHORT,''),    
    ST.Notes2,    
    ORDERS.Type,    
    ISNULL(CL2.CODE,''),    
    ORDERS.CONSIGNEEKEY  --CS04    
  FROM ORDERS ORDERS (NOLOCK)   
  JOIN PACKHEADER PACKHEADER (NOLOCK) ON (ORDERS.OrderKey = PACKHEADER.OrderKey)  
  JOIN PACKDETAIL PACKDETAIL (NOLOCK) ON (PACKHEADER.PickSlipNo = PACKDETAIL.PickSlipNo)    
  JOIN SKU SKU (NOLOCK) ON (PACKDETAIL.Sku = SKU.Sku AND PACKDETAIL.StorerKey = SKU.StorerKey)  
  JOIN PACK p (NOLOCK) ON p.packkey=sku.packkey  
  LEFT JOIN STORER ST (NOLOCK) ON ST.STORERKEY = ORDERS.CONSIGNEEKEY AND ST.[TYPE] = '2' --ML01     
  LEFT JOIN CODELKUP CL(NOLOCK) ON CL.LISTNAME = 'REPORTCFG' AND CL.Code = 'SHOWSAMPLE'       
             AND CL.Long = 'r_dw_ucc_carton_label_57' AND CL.Storerkey = ORDERS.StorerKey --ML01     
  LEFT JOIN CODELKUP CL2 (NOLOCK) ON CL2.LISTNAME = 'LOGISMPLBL' AND CL2.STORERKEY = ORDERS.STORERKEY --ML01  
 WHERE ORDERS.StorerKey = @cStorerKey   
   AND PACKHEADER.PickSlipNo = @cPickSlipNo   
   AND PACKDETAIL.CartonNo BETWEEN @nFromCartonNo AND @nToCartonNo   
 GROUP BY ORDERS.storerkey,ORDERS.orderkey,   
          ORDERS.ExternOrderKey,ORDERS.ExternPOKey,  
          ORDERS.C_Company,  
          ORDERS.C_Address1,   
          ORDERS.C_Address2,  
          ORDERS.C_Address3,  
          ORDERS.C_Address4,    
          ORDERS.C_City,   
          ORDERS.C_State,   
          ORDERS.C_Zip,   
          ORDERS.C_Country,   
          ORDERS.OrderGroup,                                                   --CS02  
          PACKHEADER.PickSlipNo,PACKDETAIL.LabelNo,   
          PACKDETAIL.SKU,SKU.HazardousFlag,ORDERS.Route ,                        --CS01  
          PACKDETAIL.AddDate ,PACKDETAIL.qty,p.casecnt,PACKDETAIL.CartonNo,ORDERS.c_contact1,ISNULL(CL.SHORT,''),       --CS02  --CS04           
          ST.Notes2,    
    ORDERS.Type,    
    ISNULL(CL2.CODE,''),    
    ORDERS.CONSIGNEEKEY         
            
   DECLARE CUR_RESULT CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
   SELECT DISTINCT Pickslipno,sku,ExternOrdKey,CtnNo,Ctncount     
   FROM   #TEMPUCCLBL57      
   WHERE pickslipno = @cPickSlipNo  
   AND Storerkey = @cStorerKey    
   ORDER BY SKU  
    
   OPEN CUR_RESULT     
       
   FETCH NEXT FROM CUR_RESULT INTO @c_GetPickslipno,@c_sku,@c_Externorderkey,@n_getctnno ,@n_getCtnCount     
       
   WHILE @@FETCH_STATUS <> -1    
   BEGIN       
    --SELECT @c_sku AS '@c_sku',@c_Externorderkey AS '@c_Externorderkey'  
    --IF @c_presku <> @c_sku    
    --BEGIN  
      SELECT @n_startCtn = MIN(cartonno)  
      FROM   PACKDETAIL PD WITH (NOLOCK)  
      WHERE  PD.PickSlipNo = @c_GetPickslipno  
         AND sku = @c_sku  
           
      --END  
        
      SELECT @c_packkey = Packkey  
      FROM   SKU(NOLOCK)  
      WHERE  SKU       = @c_sku  
        AND StorerKey  = @cStorerKey  
           
           
      SELECT @n_Casecnt = Casecnt  
      FROM   PACK P WITH (NOLOCK)  
      WHERE  P.PackKey = @c_packkey  
                      
      SELECT @n_GetPQty = SUM(qty)  
      FROM   PACKDETAIL PD WITH (NOLOCK)  
      WHERE  PD.PickSlipNo = @c_GetPickslipno  
        AND sku = @c_sku  
        AND PD.CartonNo BETWEEN @n_startCtn AND @n_getctnno  
      GROUP BY PD.SKU  
      
    IF @n_Casecnt IS NULL OR @n_Casecnt=0  
    BEGIN  
     SET @n_Casecnt = 1  
    END  
      
    SET @n_PQty = @n_GetPQty/@n_Casecnt  
      
      
    SELECT @n_GetTTLQty = SUM(OD.QtyAllocated + OD.QtyPicked)  
    FROM ORDERDETAIL OD WITH (NOLOCK)  
    WHERE OD.ExternOrderKey=@c_Externorderkey  
    AND od.Sku = @c_sku  
    AND od.StorerKey=@cStorerKey   
      
  
    SET @n_TTLQty = @n_GetTTLQty/@n_Casecnt  
  
     --CS04 Start    
    
    SET @c_facility = ''    
    SET @c_consigneekey = ''    
    SET @c_getcontact1 = 'Y'    
       
    SELECT top 1 @c_facility = facility    
          ,@c_consigneekey = consigneekey    
    FROM ORDERS (nolock)    
    WHERE externorderkey = @c_Externorderkey    
    AND storerkey = @cStorerKey    
       
       IF (@c_facility='WGQAP' and @c_consigneekey='1096')  OR     
          (@c_facility='YPCN1' and @c_consigneekey= '1098') OR      
          (@c_facility='BULIM' and @c_consigneekey='1096')     
       BEGIN    
      SET @c_getcontact1 = 'Y'    
    END    
    ELSE    
    BEGIN    
      SET @c_getcontact1 = 'N'    
    END    
  
 --CS04 End    
      
   -- SELECT @n_PQty AS '@n_PQty',@n_GetTTLQty AS '@n_GetTTLQty',@c_sku AS '@c_sku'  
      
    UPDATE #TEMPUCCLBL57  
    SET PQTY = CONVERT(Nvarchar(10),@n_PQty),  
        TTLQty = CONVERT(Nvarchar(10),@n_TTLQty),  
       --Ctncount =   
        BoxNo = CONVERT(Nvarchar(10),@n_PQty) + ' of ' + CONVERT(Nvarchar(10),@n_TTLQty),  
        CContact1 = CASE WHEN @c_getcontact1 = 'N' THEN '' ELSE CContact1 END                  --CS04    
    WHERE Pickslipno=@cPickSlipNo  
    AND SKU = @c_sku  
    AND ExternOrdKey=@c_Externorderkey    
    AND CtnNo = @n_getctnno    
      
    SET @c_packkey = ''  
    SET @n_Casecnt = 1  
    SET @n_GetPQty = 0  
    SET @n_PQty = 0  
    SET @n_TTLQty = 0  
    SET @n_GetTTLQty = 0  
    SET @c_presku = @c_sku  
      
      FETCH NEXT FROM CUR_RESULT INTO @c_GetPickslipno,@c_sku,@c_Externorderkey ,@n_getctnno,@n_getCtnCount    
   END      
   CLOSE CUR_RESULT  
   DEALLOCATE CUR_RESULT       
         
    --CS03 start      
    SET @n_cntsku = 1      
    SELECT @n_cntsku = COUNT(DISTINCT sku)  
    FROM #TEMPUCCLBL57  
    WHERE Pickslipno= @cPickSlipNo  
  
  --IF @n_cntsku > 1  
  --BEGIN  
  -- DELETE #TEMPUCCLBL57  
  -- WHERE Rowid >1  
     
  --END  
  
  --START ML01
  SELECT TOP 1 @c_showsample = ShowSample,    
     @c_notes2 = Notes2,    
     @c_type = type,    
     @c_clcode = clcode,    
     @c_consignkey = consigneekey    
  FROM #TEMPUCCLBL57      
          
  SELECT @n_qty = SUM(PD.Qty)      
  FROM PACKDETAIL PD WITH (NOLOCK)      
  WHERE PD.PICKSLIPNO = @cPickSlipNo    
  AND PD.CARTONNO = @cFromCartonNo     
    
  IF @n_cntsku > 1      
  BEGIN      
     INSERT INTO #TEMPUCCLBL57_1(      
		Pickslipno,      
		labelno,      
		ExternOrdKey,      
		ExtenPOKey,      
		Storerkey,      
     CCompany,      
     CAddress,      
     CCityState,      
     CCountry,      
     ORDGrp,                        
     SKU,      
     HFlag,      
     PQty,      
     TTLQty,      
	  OrderKey,      
     BoxNo,      
     OHRoute,                             
	  CContact1,                            
	  ShowSample      
      )                    
  SELECT TOP 1 Pickslipno,      
        labelno,      
        ExternOrdKey,      
        ExtenPOKey,      
        Storerkey,      
        CCompany,      
        CAddress,      
        CCityState,      
        CCountry,      
        ORDGrp,      
        --CASE WHEN ORDGrp = 'S01' THEN ' ' ELSE SKU END SKU,                  
        'MIX-' + CONVERT(NVARCHAR(5),@n_cntsku)  SKU,        
        CASE WHEN HFlag = 'Y' THEN '*' ELSE '' END AS Hflag,      
        CASE WHEN ORDGrp = 'S01' THEN ' 'ELSE PQty END AS PQty,      
        CASE WHEN ORDGrp = 'S01' THEN ' ' ELSE TTLQty END  AS TTLQty,      
		  OrderKey,      
        CASE WHEN ORDGrp = 'S01' THEN ' ' ELSE BoxNo END  AS BoxNo,      
        OHRoute,                             
        CContact1                               
        ,'N' AS  ShowSample      
  FROM #TEMPUCCLBL57 AS t       
  ORDER BY t.Pickslipno,t.SKU      
          
     SET @QTY = @QTY - 1      
     SET @c_ResultRowCtn = CAST(@@ROWCOUNT AS VARCHAR(10))       
      
  IF @c_notes2 <> 'SGRETAILER' AND @c_type <> 'WR' AND @c_consignkey = @c_clcode AND @c_showsample = 'Y'      
  BEGIN      
     SELECT @QTY = @n_qty      
  --SET @QTY = 5      
        WHILE @QTY >=1      
         BEGIN      
        INSERT INTO #TEMPUCCLBL57_1(      
			 Pickslipno,      
          labelno,      
			 ExternOrdKey,      
			 ExtenPOKey,      
		 Storerkey,      
       CCompany,      
       CAddress,      
       CCityState,      
       CCountry,      
       ORDGrp,                       
       SKU,      
       HFlag,      
       PQty,      
       TTLQty,      
		 OrderKey,      
       BoxNo,      
       OHRoute,                            
		 CContact1,                          
		 ShowSample      
    )                    
     SELECT         
			''          
      , ''        
      , ''        
      , ''        
      , ''        
      , ''        
      , ''        
      , ''        
      , ''        
      , ''        
      , ''      
      , ''        
      , ''        
      , ''        
      , ''       
      , ''        
      , ''        
      , ''        
      , 'Y'      
     SET @QTY = @QTY - 1      
        END      
        SELECT * FROM #TEMPUCCLBL57_1      
   END      
   ELSE       
      BEGIN      
         SELECT * FROM #TEMPUCCLBL57_1      
      END      
  END      
  ELSE       
  BEGIN      
     INSERT INTO #TEMPUCCLBL57_1(      
		Pickslipno,      
		labelno,      
		ExternOrdKey,      
		ExtenPOKey,      
		Storerkey,      
     CCompany,      
     CAddress,      
     CCityState,      
     CCountry,      
     ORDGrp,                   
     SKU,      
     HFlag,      
     PQty,      
     TTLQty,      
	  OrderKey,      
     BoxNo,      
     OHRoute,                              
	  CContact1,                           
	  ShowSample      
      )                    
  SELECT Pickslipno,      
        labelno,      
        ExternOrdKey,      
        ExtenPOKey,      
        Storerkey,      
        CCompany,      
        CAddress,      
        CCityState,      
        CCountry,      
        ORDGrp,      
        --CASE WHEN ORDGrp = 'S01' THEN ' ' ELSE SKU END SKU,    
		  SKU,  
        --'MIX-' + CONVERT(NVARCHAR(5),@n_cntsku)  SKU,        
        CASE WHEN HFlag = 'Y' THEN '*' ELSE '' END AS Hflag,      
        CASE WHEN ORDGrp = 'S01' THEN ' 'ELSE PQty END AS PQty,      
        CASE WHEN ORDGrp = 'S01' THEN ' ' ELSE TTLQty END  AS TTLQty,      
        OrderKey,      
        CASE WHEN ORDGrp = 'S01' THEN ' ' ELSE BoxNo END  AS BoxNo,      
        OHRoute,                           
        CContact1                           
        ,'N' AS  ShowSample      
  FROM #TEMPUCCLBL57 AS t       
  ORDER BY t.Pickslipno,t.SKU      
          
     SET @QTY = @QTY - 1      
     SET @c_ResultRowCtn = CAST(@@ROWCOUNT AS VARCHAR(10))       
      
  IF @c_notes2 <> 'SGRETAILER' AND @c_type <> 'WR' AND @c_consignkey = @c_clcode AND @c_showsample = 'Y'      
  BEGIN      
     SELECT @QTY = @n_qty      
  --SET @QTY = 5      
        WHILE @QTY >=1      
         BEGIN      
        INSERT INTO #TEMPUCCLBL57_1(      
			Pickslipno,      
       labelno,      
       ExternOrdKey,      
       ExtenPOKey,      
		 Storerkey,      
       CCompany,      
       CAddress,      
       CCityState,      
       CCountry,      
       ORDGrp,                         
       SKU,      
       HFlag,      
       PQty,      
       TTLQty,      
		 OrderKey,      
       BoxNo,      
       OHRoute,                           
		 CContact1,                           
		 ShowSample      
    )                    
     SELECT         
			''          
      , ''        
      , ''    
      , ''        
      , ''        
      , ''        
      , ''        
      , ''        
      , ''        
      , ''        
      , ''      
      , ''        
      , ''        
      , ''        
      , ''       
      , ''        
      , ''        
      , ''        
      , 'Y'      
     SET @QTY = @QTY - 1      
   END      
        SELECT * FROM #TEMPUCCLBL57_1      
   END      
   ELSE       
      BEGIN      
         SELECT * FROM #TEMPUCCLBL57_1      
      END      
  END      
 --CS03 END 
 --END ML01
     
--WL01 Start  
LABELWITHSKU:  
   IF @cType = '4X6'  
   BEGIN   
      SELECT OH.Externorderkey  
           , OH.ExternPOKey  
           , ISNULL(OH.C_Contact1,'') AS C_Contact1  
           , ISNULL(OH.C_Company,'')  AS C_Company  
           , ISNULL(OH.C_Address1,'') AS C_Address1  
           , ISNULL(OH.C_Address2,'') AS C_Address2  
           , ISNULL(OH.C_Address3,'') AS C_Address3  
           , ISNULL(OH.C_Address4,'') AS C_Address4  
           , ISNULL(OH.C_Zip,'')      AS C_Zip  
           , ISNULL(OH.C_Country,'')  AS C_Country  
           , OH.[Route]  
           , PD.LabelNo  
           , PD.CartonNo  
           , PD.SKU  
           , PD.Qty  
      FROM ORDERS OH (NOLOCK)  
      JOIN PACKHEADER PH (NOLOCK) ON PH.ORDERKEY = OH.ORDERKEY  
      JOIN PACKDETAIL PD (NOLOCK) ON PD.Pickslipno = PH.Pickslipno  
      WHERE OH.StorerKey = @cStorerKey   
        AND PH.PickSlipNo = @cPickSlipNo   
        AND PD.CartonNo BETWEEN @nFromCartonNo AND @nToCartonNo   
      ORDER BY PH.Pickslipno, PD.CartonNo, PD.SKU  
        
      SET @c_ResultRowCtn = CAST(@@ROWCOUNT AS VARCHAR(10))    
   END  
   --WL01 Start  
QUIT_SP:  
   SET @d_Trace_EndTime = getdate()  
     
   EXEC isp_InsertTraceInfo         
      @c_TraceCode = 'CartonLabel_57',        
      @c_TraceName = 'isp_Print_UCC_CartonLabel_57',        
      @c_starttime = @d_Trace_StartTime,        
      @c_endtime   = @d_Trace_EndTime,        
      @c_step1     = @c_UserName,        
      @c_step2 = @cStorerKey,               
      @c_step3 = @cPickSlipNo,              
      @c_step4 = @cFromCartonNo,            
      @c_step5 = @cToCartonNo,              
      @c_col1 = @cType,                 
      @c_col2 = @c_ResultRowCtn,        
      @c_col3 = @n_cntsku,        
      @c_col4 = '',        
      @c_col5 = '',        
      @b_Success = 1,        
      @n_Err = 0,        
      @c_ErrMsg = ''                    
        
END  

GO