SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/    
/* Stored Procedure: isp_pod_34                                         */    
/* Creation Date:                                                       */    
/* Copyright: IDS                                                       */    
/* Written by:                                                          */    
/*                                                                      */    
/* Purpose: WMS-21910 [CN] UA_View Report_POD-CR                        */    
/*          Copy from isp_pod_26                                        */  
/*                                                                      */    
/* Called By: r_dw_pod_26                                               */     
/*                                                                      */    
/* Parameters: (Input)  @c_mbolkey   = MBOL No / MBOLStart              */                              
/*                      @c_exparrivaldate = Expected arrival date /     */  
/*                                          MBOLEnd                     */    
/*                      @c_InputStorerkey = Storerkey                   */  
/*                                                                      */    
/* PVCS Version: 1.0                                                    */    
/*                                                                      */    
/* Version: 5.4                                                         */    
/*                                                                      */    
/* Data Modifications:                                                  */    
/*                                                                      */    
/* Updates:                                                             */    
/* Date         Author    Ver. Purposes                                 */    
/* 24-Mar-2023  CSCHONG   1.0  DevopsScripts Combine                    */  
/************************************************************************/    
CREATE    PROCEDURE [dbo].[isp_pod_34]    
        @c_mbolkey         NVARCHAR(10),     
        @c_exparrivaldate  NVARCHAR(30) = '',  
        @c_InputStorerkey  NVARCHAR(10) = '',  
        @c_DocType         NVARCHAR(10) = 'N',  
        @c_Facility        NVARCHAR(10) = 'N'   
AS    
BEGIN    
   SET NOCOUNT ON    
   SET ANSI_NULLS OFF      
   SET QUOTED_IDENTIFIER OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    
    
   DECLARE @c_orderkey NVARCHAR(10),    
           @c_type     NVARCHAR(10),    
           @n_casecnt  int,    
           @n_qty      int,    
           @n_totalcasecnt int,    
           @n_totalqty     int    
    
   DECLARE @n_TotalWeight  FLOAT                                                                        
         , @n_TotalCube    FLOAT                                                                        
    
         , @n_Weight       FLOAT                                                                        
         , @n_Cube         FLOAT                                                                        
         , @n_SetMBOLAsOrd          INT                                                                 
         , @n_OrderShipAddress      INT                                                                 
         , @n_WgtCubeFromPackInfo   INT                                                                 
         , @n_CountCntByLabelno     INT                                                                  
         , @c_Storerkey             NVARCHAR(15)                                                        
    
         , @c_Brand                 NVARCHAR(20)                                                        
             
         , @n_PrintAfterPacked      INT                                                                 
         , @c_printdate             NVARCHAR(30)                                                    
         , @c_printby               NVARCHAR(30)                                                           
         , @c_showfield             NVARCHAR(1)                                          
    
         , @n_RemoveEstDelDate      INT                                                                 
         , @n_RemoveItemName        INT                                                                 
         , @n_RemoveFax             INT                                                                 
         , @n_RemovePrintInfo       INT                                                                 
         , @n_RemoveCartonSumm      INT                                                                                
         , @n_ReplIDSWithLFL        INT                                                                  
    
         , @n_ShowRecDateTimeRmk    INT                                                                 
         , @c_IncFontSize           NVARCHAR(1)                                                    
         , @n_ShowPageNo            INT                                                  
         , @n_ShowOrderInfo01       INT                                                               
         , @c_MbolkeyEnd            NVARCHAR(30)                                                     
         , @c_GetMbolKey            NVARCHAR(10) = ''  
    
   SET @n_Weight              = 0.00                                                                    
   SET @n_Cube                = 0.00                                                                    
   SET @n_SetMBOLAsOrd        = 0                                                                       
   SET @n_OrderShipAddress    = 0                                                                       
   SET @n_WgtCubeFromPackInfo = 0                                                                       
   SET @n_CountCntByLabelno   = 0                                                                       
   SET @c_Storerkey           = ''                                                                      
    
   SET @c_Brand               = ''                                                                      
    
   SET @n_PrintAfterPacked    = 0                                                                       
   SET @c_printdate           = REPLACE(CONVERT(NVARCHAR(20),GETDATE(),120),'-','/')                     
   SET @c_printby             = SUSER_NAME()                                                             
    
   SET @n_RemoveEstDelDate    = 0                                                                       
   SET @n_RemoveItemName      = 0                                                                       
   SET @n_RemoveFax           = 0                                                                       
   SET @n_RemovePrintInfo     = 0                                                                       
   SET @n_RemoveCartonSumm    = 0                                                                                      
   SET @n_ReplIDSWithLFL      = 0                                                                       
    
   SET @n_ShowRecDateTimeRmk  = 0                                                                       
   SET @c_IncFontSize         = ''                                                                  
   SET @n_ShowPageNo          = 0                                                                
   SET @n_ShowOrderInfo01     = 0                                                            
   SET @c_MbolkeyEnd          = ''                                                     
  
   CREATE TABLE #AllMBOLKey  
   (MBOLKEY           NVARCHAR(30),  
    Orderkey          NVARCHAR(10) )  
  
   IF @c_InputStorerkey = NULL SET @c_InputStorerkey = ''  
  
   IF @c_exparrivaldate = NULL SET @c_exparrivaldate = ''  
  
   --Check if parm 2 is a valid mbolkey, if yes, print a range of mbolkey  
   IF EXISTS (SELECT 1 FROM MBOL (NOLOCK) WHERE MBOLKEY = @c_exparrivaldate)  
   BEGIN  
      SET @c_MbolkeyEnd = @c_exparrivaldate  
      SET @c_exparrivaldate = ''  
  
      INSERT INTO #AllMBOLKey  
      SELECT DISTINCT MD.MBOLKEY, ORD.ORDERKEY  
      FROM MBOLDETAIL MD (NOLOCK)  
      JOIN ORDERS ORD (NOLOCK) ON ORD.ORDERKEY = MD.ORDERKEY  
      WHERE MD.MBOLKEY BETWEEN @c_mbolkey AND @c_MbolkeyEnd  
      AND ORD.Storerkey = CASE WHEN @c_InputStorerkey = '' THEN ORD.Storerkey ELSE @c_InputStorerkey END   
      AND ORD.DocType = @c_DocType  
      AND ORD.Facility = @c_Facility   
   END  
   ELSE  
   BEGIN  
      INSERT INTO #AllMBOLKey  
      SELECT DISTINCT MD.MBOLKEY, ORD.ORDERKEY  
      FROM MBOLDETAIL MD (NOLOCK)  
      JOIN ORDERS ORD (NOLOCK) ON ORD.ORDERKEY = MD.ORDERKEY  
      WHERE MD.MBOLKEY = @c_mbolkey  
      AND ORD.DocType = @c_DocType  
      AND ORD.Facility = @c_Facility 
   END  
    
   CREATE TABLE #POD    
   (mbolkey           NVARCHAR(10) null,    
    MbolLineNumber    NVARCHAR(5)  null,    
    ExternOrderKey    NVARCHAR(50) null,  
    Orderkey          NVARCHAR(10) null,    
    Type              NVARCHAR(10) null,    
    EditDate          datetime null,    
    Company           NVARCHAR(45)  null,       
    CaseCnt           int       null,    
    Qty               int        null,    
    TotalCaseCnt      int       null,    
    TotalQty          int        null,       
    leadtime        int null,    
    logo NVARCHAR(60) null,    
    B_Address1 NVARCHAR(45) null,    
    B_Contact1 NVARCHAR(30) null,    
    B_Phone1 NVARCHAR(18) null,    
    B_Fax1 NVARCHAR(18) null,    
    Susr2 NVARCHAR(20) null,    
    MbolLoadkey NVARCHAR(10) null,    
    shipto NVARCHAR(65) null,    
    shiptoadd1 NVARCHAR(45) null,    
    shiptoadd2 NVARCHAR(45) null,    
    shiptoadd3 NVARCHAR(45) null,    
    shiptoadd4 NVARCHAR(45) null,    
    shiptocity NVARCHAR(45) null,    
    shiptocontact1 NVARCHAR(30) null,    
    shiptocontact2 NVARCHAR(30) null,    
    shiptophone1 NVARCHAR(18) null,    
    shiptophone2 NVARCHAR(18) null,        
    note1a NVARCHAR(216) null,    
    note1b NVARCHAR(214) null,    
    note2a NVARCHAR(216) null,    
    note2b NVARCHAR(214) null,       
    Weight        FLOAT NULL,    
    Cube          FLOAT NULL,    
    TotalWeight   FLOAT NULL,    
    TotalCube     FLOAT NULL,      
    Domain NVARCHAR(10)  NULL,    
    ConsigneeKey   NVARCHAR(45),  
    OrderInfo01    NVARCHAR(30)   
    )     
    
 
   SELECT TOP 1 @c_Storerkey = OH.Storerkey    
   FROM MBOLDETAIL MB WITH (NOLOCK)    
   JOIN ORDERS     OH WITH (NOLOCK) ON (MB.Orderkey = OH.Orderkey)    
   WHERE MB.MBOLKey = @c_MBOLKey    
   ORDER BY MB.MBOLLineNumber    
    
   SELECT @n_SetMBOLAsOrd        = ISNULL(MAX(CASE WHEN Code = 'SETMBOLASORD' THEN 1 ELSE 0 END),0)    
         ,@n_OrderShipAddress    = ISNULL(MAX(CASE WHEN Code = 'ORDERSHIPADDRESS' THEN 1 ELSE 0 END),0)    
         ,@n_WgtCubeFromPackInfo = ISNULL(MAX(CASE WHEN Code = 'WGTCUBEFROMPACKINFO' THEN 1 ELSE 0 END),0)    
         ,@n_CountCntByLabelno   = ISNULL(MAX(CASE WHEN Code = 'COUNTCARTONBYLABELNO' THEN 1 ELSE 0 END),0)   
         ,@n_PrintAfterPacked    = ISNULL(MAX(CASE WHEN Code = 'PRINTAFTERPACKED'   THEN 1 ELSE 0 END),0)        
         ,@c_showfield           = ISNULL(MAX(CASE WHEN Code = 'ShowField'   THEN 1 ELSE 0 END),0)           
         ,@n_RemoveEstDelDate    = ISNULL(MAX(CASE WHEN Code = 'RemoveEstDelDate'THEN 1 ELSE 0 END),0)          
         ,@n_RemoveItemName      = ISNULL(MAX(CASE WHEN Code = 'RemoveItemName'  THEN 1 ELSE 0 END),0)          
         ,@n_RemoveFax           = ISNULL(MAX(CASE WHEN Code = 'RemoveFax'       THEN 1 ELSE 0 END),0)          
         ,@n_RemovePrintInfo     = ISNULL(MAX(CASE WHEN Code = 'RemovePrintInfo' THEN 1 ELSE 0 END),0)          
         ,@n_RemoveCartonSumm    = ISNULL(MAX(CASE WHEN Code = 'RemoveCartonSumm'THEN 1 ELSE 0 END),0)          
         ,@n_ReplIDSWithLFL      = ISNULL(MAX(CASE WHEN Code = 'ReplIDSWithLFL'  THEN 1 ELSE 0 END),0)          
         ,@n_ShowRecDateTimeRmk  = ISNULL(MAX(CASE WHEN Code = 'ShowRecDateTimeRmk'THEN 1 ELSE 0 END),0)       
         ,@n_ShowPageNo          = ISNULL(MAX(CASE WHEN Code = 'ShowPageNo' THEN 1 ELSE 0 END),0)             
         ,@n_ShowOrderInfo01     = ISNULL(MAX(CASE WHEN Code = 'ShowOrderInfo01'  THEN 1 ELSE 0 END),0)          
   FROM CODELKUP WITH (NOLOCK)    
   WHERE ListName = 'REPORTCFG'    
   AND   Storerkey= @c_Storerkey    
   AND   Long = 'r_dw_pod_26'    
   AND   ISNULL(Short,'') <> 'N'    
    
        
   
 SELECT @c_IncFontSize = ISNULL(SHORT,'')    
 FROM CODELKUP (NOLOCK)    
 WHERE ListName = 'REPORTCFG'    
 AND   Storerkey= @c_Storerkey    
 AND   Long = 'r_dw_pod_26'    
 AND   CODE = 'IncFontSize'    
   
   IF @n_PrintAfterPacked = 1     
   BEGIN    
      IF EXISTS (    
                  SELECT 1     
                  FROM MBOLDETAIL MB WITH (NOLOCK)    
                  JOIN ORDERS     OH WITH (NOLOCK) ON (MB.Orderkey = OH.Orderkey)    
                  WHERE MB.MBOLKey = @c_mbolkey    
                  AND OH.Status < '5'    
                )    
      BEGIN    
         GOTO QUIT    
      END    
   END    
  
   SELECT DISTINCT STORER.Storerkey, CASE WHEN ISNULL(CODELKUP.Code,'') <> '' THEN     
                                 CODELKUP.UDF01     
                            ELSE STORER.SUSR1 END AS SUSR1_UDF01    
   INTO #TMP_STORER    
   FROM ORDERS (NOLOCK)    
   JOIN STORER (NOLOCK) ON ORDERS.Storerkey = STORER.Storerkey    
   LEFT JOIN CODELKUP (NOLOCK) ON ORDERS.Storerkey = CODELKUP.Storerkey AND CODELKUP.Listname = 'PODBARCODE'    
   WHERE ORDERS.Mbolkey = @c_Mbolkey    
    
    INSERT INTO #POD    
    ( mbolkey,        MbolLineNumber ,    ExternOrderKey,        Orderkey,        type,    
      EditDate,       Company,            CaseCnt,               Qty,                          
      TotalCaseCnt,   TotalQty,           leadtime,              Logo,    
      B_Address1,     B_Contact1,         B_Phone1,              B_Fax1,    
      Susr2,          MbolLoadkey,        ShipTo,                ShipToAdd1,    
      ShipToAdd2,     ShipToAdd3,         ShipToAdd4,            ShipToCity,    
      ShipToContact1, ShipToContact2,     ShipToPhone1,          ShipToPhone2,    
      note1a,         note1b,             note2a,                note2b,    
      Weight,         Cube,               TotalWeight,           TotalCube,                       
      Domain,         ConsigneeKey,       OrderInfo01  
      )        
    SELECT     
      a.mbolkey,     b.MbolLineNumber,    b.ExternOrderKey,    b.Orderkey,    c.type,            
      a.editdate,    f.company,           0,                   0,    
      0,             0,                   ISNULL(CAST(e.Short AS int),0),     f.logo,    
      f.B_Address1,  f.B_Contact1,        f.B_Phone1,          f.B_fax1,    
      f.Susr2,        
         --c=order d=consignee f=storer h=billto+consignee        
         CASE WHEN ISNULL(j.Susr1_UDF01,0) & 4 = 4 THEN c.MBOLKey    
              ELSE c.Loadkey END AS Mbolloadkey,    
         CASE WHEN ISNULL(f.SUSR3,0) = 1 THEN CASE WHEN h.Storerkey IS NULL THEN c.C_Company ELSE h.Company END     
              ELSE      
                CASE WHEN ISNULL(j.Susr1_UDF01,0) & 2 = 2 THEN    
                   '('+RTRIM(d.Storerkey) + ')' + d.Company    
                ELSE     
                CASE WHEN ISNULL(j.Susr1_UDF01,0) & 8 = 8 THEN    
                       '('+RTRIM(ISNULL(c.Consigneekey,'')) + '-' + RTRIM(ISNULL(c.Billtokey,'')) +')' + c.C_Company    
                ELSE '('+RTRIM(ISNULL(c.Consigneekey,''))+')'+c.C_Company END     
              END     
         END AS Shipto,    
         CASE WHEN ISNULL(f.SUSR3,0) = 1 THEN CASE WHEN h.Storerkey IS NULL THEN c.C_Address1 ELSE h.Address1 END    
              ELSE      
              CASE WHEN ISNULL(j.Susr1_UDF01,0) & 2 = 2 THEN    
                   d.Address1 ELSE c.C_Address1 END     
         END AS ShipToAdd1,    
         CASE WHEN ISNULL(f.SUSR3,0) = 1 THEN CASE WHEN h.Storerkey IS NULL THEN c.C_Address2 ELSE h.Address2 END    
              ELSE      
              CASE WHEN ISNULL(j.Susr1_UDF01,0) & 2 = 2 THEN    
                   d.Address2 ELSE c.C_Address2 END     
         END AS ShipToAdd2,    
         CASE WHEN ISNULL(f.SUSR3,0) = 1 THEN CASE WHEN h.Storerkey IS NULL THEN c.C_Address3 ELSE h.Address3 END   
              ELSE     
              CASE WHEN ISNULL(j.Susr1_UDF01,0) & 2 = 2 THEN    
                   d.Address3 ELSE c.C_Address3 END     
         END AS ShipToAdd3,    
         CASE WHEN ISNULL(f.SUSR3,0) = 1 THEN CASE WHEN h.Storerkey IS NULL THEN c.C_Address4 ELSE h.Address4 END     
              ELSE     
              CASE WHEN ISNULL(j.Susr1_UDF01,0) & 2 = 2 THEN    
                   d.Address4 ELSE c.C_Address4 END     
         END AS ShipToAdd4,    
         CASE WHEN ISNULL(f.SUSR3,0) = 1 THEN CASE WHEN h.Storerkey IS NULL THEN c.C_City ELSE h.City END       
              ELSE     
              CASE WHEN ISNULL(j.Susr1_UDF01,0) & 2 = 2 THEN    
                   d.City ELSE c.C_City END     
         END AS ShipToCity,    
         CASE WHEN ISNULL(f.SUSR3,0) = 1 THEN CASE WHEN h.Storerkey IS NULL THEN c.C_Contact1 ELSE h.Contact1 END     
              ELSE     
              CASE WHEN ISNULL(j.Susr1_UDF01,0) & 2 = 2 THEN    
                   d.Contact1 ELSE c.C_Contact1 END     
         END AS ShipToContact1,    
         CASE WHEN ISNULL(f.SUSR3,0) = 1 THEN CASE WHEN h.Storerkey IS NULL THEN c.C_Contact2 ELSE h.Contact2 END    
              ELSE     
              CASE WHEN ISNULL(j.Susr1_UDF01,0) & 2 = 2 THEN    
                   d.Contact2 ELSE c.C_Contact2 END     
         END AS ShipToContact2,    
         CASE WHEN ISNULL(f.SUSR3,0) = 1 THEN CASE WHEN h.Storerkey IS NULL THEN c.C_Phone1 ELSE h.Phone1 END         
              ELSE     
              CASE WHEN ISNULL(j.Susr1_UDF01,0) & 2 = 2 THEN    
                   d.Phone1 ELSE c.C_Phone1 END     
         END AS ShipToPhone1,    
         CASE WHEN ISNULL(f.SUSR3,0) = 1 THEN CASE WHEN h.Storerkey IS NULL THEN c.C_Phone2 ELSE h.Phone2 END        
              ELSE     
              CASE WHEN ISNULL(j.Susr1_UDF01,0) & 2 = 2 THEN    
                   d.Phone2 ELSE c.C_Phone2 END     
         END AS ShipToPhone2,            
         LEFT(CONVERT(NVARCHAR(430),f.Notes1),216) AS note1a,    
         SUBSTRING(CONVERT(NVARCHAR(430),f.Notes1),217,214) AS note1b,    
         LEFT(CONVERT(NVARCHAR(430),f.Notes2),216) AS note2a,    
         SUBSTRING(CONVERT(NVARCHAR(430),f.Notes2),217,214) AS note2b,     
         ISNULL(b.Weight,0),    
         ISNULL(b.Cube,0),    
         0,    
         0,       
         g.Short     
         ,CASE WHEN @c_showfield='1' AND ISNULL(c.ConsigneeKey,'') <> '' THEN c.ConsigneeKey ELSE '' END  
         ,CASE WHEN @n_ShowOrderInfo01 = 1 THEN ISNULL(k.OrderInfo01,'') ELSE '' END             
    FROM mbol a (nolock) JOIN MBOLDETAIL b  WITH (nolock) ON a.mbolkey = b.mbolkey            
    JOIN ORDERS c WITH (nolock) ON b.orderkey = c.orderkey    
    LEFT JOIN STORER d WITH (nolock) ON c.consigneekey = d.storerkey       
    JOIN STORER f WITH (nolock) ON c.storerkey = f.storerkey        
    LEFT JOIN STORERCONFIG  i WITH (NOLOCK) ON (i.Storerkey = c.Storerkey)    
                                            AND(i.Configkey = 'CityLdTimeField')    
    LEFT JOIN CODELKUP e WITH (nolock) ON e.listname ='CityLdTime'     
                                       AND ( (i.SValue = '1' AND e.Description = c.C_City) OR    
                                             (i.SValue = '2' AND e.Description = f.City) OR    
                                             (i.SValue = '3' AND e.Description = c.Consigneekey) OR    
                                             (i.SValue = '4' AND e.Description = + RTRIM(c.BillTokey) + RTRIM(c.Consigneekey)) )    
                                       AND ( (ISNULL(RTRIM(e.Long),'')= '') OR     
                                             (ISNULL(RTRIM(e.Long),'') <> '' AND ISNULL(RTRIM(e.Long),'') = c.Facility) )    
                                       AND CONVERT( NVARCHAR(15), e.Notes) = i.Storerkey    
                                       AND ( (CONVERT( NVARCHAR(50), e.Notes2) = c.IntermodalVehicle) OR    
                                             (CONVERT( NVARCHAR(50), e.Notes2) = 'ROAD' AND ISNULL(RTRIM(c.IntermodalVehicle),'') = '') )                                                                                 
    LEFT JOIN Codelkup g WITH (nolock) ON c.Storerkey = g.Code and g.listname ='STRDOMAIN'       
    LEFT JOIN STORER h WITH (NOLOCK) ON RTRIM(c.Billtokey) + RTRIM(c.Consigneekey) = h.storerkey           
    JOIN #TMP_STORER j WITH (NOLOCK) ON c.Storerkey = j.Storerkey    
    LEFT JOIN OrderInfo k WITH (NOLOCK) ON k.orderkey = c.orderkey 
    JOIN #AllMBOLKey l WITH (NOLOCK) ON l.MBOLKEY = a.MBOLKEY      

      
    DECLARE cur_Mbol CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
    SELECT DISTINCT MBOLKEY  
    FROM #POD  
  
    OPEN cur_Mbol  
  
    FETCH NEXT FROM cur_Mbol INTO @c_GetMbolKey  
  
    WHILE @@FETCH_STATUS <> -1  
    BEGIN  
  
       SELECT @c_orderkey = MIN(orderkey)    
       FROM #POD (nolock)   
       WHERE mbolkey = @c_GetMbolKey  
        
       WHILE @c_orderkey IS NOT NULL    
       BEGIN     
         SELECT @c_type = type    
         FROM #POD (nolock)    
         WHERE orderkey = @c_orderkey     
          
         SELECT @n_casecnt = 0, @n_qty = 0    
          
         --IF @c_type = 'XDOCK'     
         IF EXISTS(SELECT code FROM CODELKUP(NOLOCK) WHERE listname = 'XDOCKTYPE' AND code = @c_type)     
            AND @n_CountCntByLabelno = 0                                                             
         BEGIN    
            SELECT @n_casecnt = COUNT(DISTINCT d.UserDefine01+d.UserDefine02),    
                   @n_qty     = SUM(d.qtyallocated + d.ShippedQty + d.QtyPicked)    
            FROM ORDERDETAIL d (nolock)    
            WHERE d.orderkey = @c_orderkey and d.status >= '5'     
            AND d.qtyallocated + d.qtypicked + d.shippedqty > 0    
         END    
         ELSE    
         BEGIN    
   
            SELECT @n_casecnt = CASE WHEN @n_CountCntByLabelno = 0     
                                     THEN COUNT(DISTINCT f.cartonno)    
                                     ELSE COUNT(DISTINCT f.labelno)    
                                     END,     
                   @n_qty     = SUM(f.qty)    
            FROM PICKHEADER e (nolock), PACKDETAIL f (nolock)    
            WHERE e.orderkey = @c_orderkey and e.PickHeaderKey = f.pickslipno     
         END    
           
 
         IF @n_SetMBOLAsOrd = 1    
         BEGIN    
            UPDATE #POD    
             SET MBOLKey     = @c_Orderkey    
               , MbolLoadkey = @c_Orderkey    
               , Totalcasecnt= @n_casecnt     
               , Totalqty    = @n_qty    
            WHERE Orderkey = @c_Orderkey    
         END    
    
         IF @n_OrderShipAddress = 1    
         BEGIN    
 
            SET @c_Brand = ''    
            SELECT TOP 1 @c_Brand = ISNULL(RTRIM(SKU.BUSR5),'')    
            FROM ORDERDETAIL OD  WITH (NOLOCK)    
            JOIN SKU         SKU WITH (NOLOCK) ON (OD.Storerkey = SKU.Storerkey)    
                                               AND(OD.Sku = SKU.Sku)    
            WHERE OD.Orderkey = @c_Orderkey    
    
            SET @c_Brand = @c_Brand + CASE WHEN @c_Brand = '' THEN '' ELSE ' ' END    

    
            UPDATE #POD    
             SET Shipto        = @c_Brand + ISNULL(RTRIM(ORDERS.C_Company),'')  
               , ShipToAdd1    = ISNULL(RTRIM(ORDERS.C_Address1),'')      
               , ShipToAdd2    = ISNULL(RTRIM(ORDERS.C_Address2),'')    
               , ShipToAdd3    = ISNULL(RTRIM(ORDERS.C_Address3),'')    
               , ShipToAdd4    = ISNULL(RTRIM(ORDERS.C_Address4),'')    
               , ShipToCity    = ISNULL(RTRIM(ORDERS.C_City),'')    
               , ShipToContact1= ISNULL(RTRIM(ORDERS.C_Contact1),'')    
               , ShipToContact2= ISNULL(RTRIM(ORDERS.C_Contact2),'')     
               , ShipToPhone1  = ISNULL(RTRIM(ORDERS.C_Phone1),'')    
               , ShipToPhone2  = ISNULL(RTRIM(ORDERS.C_Phone2),'')    
            FROM #POD     
            JOIN ORDERS (NOLOCK) ON (#POD.Orderkey = ORDERS.Orderkey)  
            WHERE #POD.Orderkey = @c_Orderkey    
         END    
    
         IF @n_WgtCubeFromPackInfo = 1    
         BEGIN    
            SET @n_Weight = 0.00    
            SET @n_Cube   = 0.00    
    
            SELECT @n_Weight = ISNULL(SUM(ISNULL(PI.Weight,0)),0)    
                 , @n_Cube   = ISNULL(SUM(ISNULL(PI.Cube,0)),0)                                          
            FROM PACKHEADER PH WITH (NOLOCK)    
            JOIN PACKINFO   PI WITH (NOLOCK) ON (PH.PickSlipNo = PI.PickSlipNo)    
            WHERE PH.Orderkey = @c_Orderkey    
    
            SELECT @n_Weight = ISNULL(CASE WHEN @n_Weight > 0 THEN @n_Weight ELSE SUM(PD.Qty * S.StdGrossWgt) END,0)                                                         
                  ,@n_Cube   = ISNULL(CASE WHEN @n_Cube > 0 THEN @n_Cube ELSE SUM(PD.Qty * S.StdCube) END,0)            
            FROM PACKHEADER PH WITH (NOLOCK)    
            JOIN PACKDETAIL PD WITH (NOLOCK) ON (PH.PickSlipNo = PD.PickSlipNo)    
            JOIN SKU        S  WITH (NOLOCK) ON (PD.Storerkey = S.Storerkey) AND (PD.Sku = S.Sku)    
            WHERE PH.Orderkey = @c_Orderkey    
     
            UPDATE #POD    
             SET Weight = @n_Weight    
               , Cube   = @n_Cube    
               , TotalWeight = @n_Weight                                                                   
               , TotalCube   = @n_Cube     
            FROM #POD     
            WHERE Orderkey = @c_Orderkey    
         END      
    
         UPDATE #POD    
         SET casecnt = ISNULL(@n_casecnt,0),    
             qty     = ISNULL(@n_qty,0)   
         WHERE orderkey = @c_orderkey     
              
         SELECT @c_orderkey = MIN(orderkey)    
         FROM #POD (nolock)    
         WHERE orderkey > @c_orderkey    
       END  
  
       IF @n_SetMBOLAsOrd = 0                                                          
       BEGIN    
          SELECT @n_totalcasecnt = SUM(casecnt),    
                 @n_totalqty     = SUM(qty)     
               , @n_TotalWeight  = SUM(Weight)                                                       
               , @n_TotalCube    = SUM(Cube)                                                          
          FROM #POD    
          WHERE mbolkey = @c_GetMbolkey  
         
          UPDATE #POD    
          SET totalcasecnt = ISNULL(@n_totalcasecnt,0)   
            , totalqty     = ISNULL(@n_totalqty,0)  
            , TotalWeight  = ISNULL(@n_TotalWeight,0)                                               
            , TotalCube    = ISNULL(@n_TotalCube,0)                                                               
          WHERE mbolkey = @c_GetMbolkey  
       END    
         
       FETCH NEXT FROM cur_Mbol INTO @c_GetMbolkey    
   END  
        
     
    
QUIT:                                                                                         
   IF CURSOR_STATUS('LOCAL' , 'cur_mbol') in (0 , 1)  
   BEGIN  
      CLOSE cur_mbol  
      DEALLOCATE cur_mbol     
   END  
  
   SELECT    
            mbolkey          
          , MbolLineNumber       
          , ExternOrderKey       
          , Orderkey            
          , Type                
          , EditDate            
          , Company             
          , CaseCnt             
          , Qty                 
          , TotalCaseCnt        
          , TotalQty            
          , leadtime            
          , logo                
          , B_Address1          
          , B_Contact1          
          , B_Phone1            
          , B_Fax1              
          , Susr2               
          , MbolLoadkey         
          , shipto              
          , shiptoadd1          
          , shiptoadd2          
          , shiptoadd3          
          , shiptoadd4          
          , shiptocity          
          , shiptocontact1       
          , shiptocontact2       
          , shiptophone1        
          , shiptophone2        
          , note1a              
          , note1b              
          , note2a              
          , note2b              
          , Weight              
          , Cube                
          , TotalWeight         
          , TotalCube           
          , Domain              
          , ConsigneeKey              
         , ISNULL(@c_exparrivaldate,'')    
         , @c_printdate, @c_printby                                                                  
         , @n_RemoveEstDelDate                                                                    
         , @n_RemoveItemName                                                                       
         , @n_RemoveFax                                                                              
         , @n_RemovePrintInfo                                                                         
         , @n_RemoveCartonSumm       
         , @n_ReplIDSWithLFL                                                                        
         , @n_ShowRecDateTimeRmk                                                                     
         , @c_IncFontSize                                                                            
         , @n_ShowPageNo                                                                            
         , @n_ShowOrderInfo01 AS ShowOrderInfo01                                                   
         , OrderInfo01                                                                             
    FROM #POD    
    ORDER BY mbolkey, MbolLineNumber  
END

GO