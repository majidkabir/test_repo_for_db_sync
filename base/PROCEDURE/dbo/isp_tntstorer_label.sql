SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
  
/************************************************************************/    
/* Store Procedure:  isp_TNTStorer_label                                */    
/* Creation Date: 04-Aug-2014                                           */    
/* Copyright: IDS                                                       */    
/* Written by: CSCHONG                                                  */    
/*                                                                      */    
/* Purpose:  SOS#316568 Jack Wills TNT Store Label                      */    
/*                                                                      */    
/* Input Parameters:  @c_Storerkey , @c_orderkey,@c_trackingNo          */    
/*                                                                      */    
/* Called By:  dw = r_dw_TNT_Store_label                                */    
/*                                                                      */    
/* PVCS Version: 1.2                                                    */    
/*                                                                      */    
/* Version: 5.4                                                         */    
/*                                                                      */    
/* Data Modifications:                                                  */    
/*                                                                      */    
/* Updates:                                                             */    
/* Date         Author  Ver   Purposes                                  */   
/* 2014-08-19   CSCHONG 1.0   Change the mapping to consigneekey (CS01) */   
/* 2014-09-15   James   1.1   Display sack id (james01)                 */  
/* 2014-09-22   James   1.2   Add PTS LOC (james02)                     */  
/* 2014-09-25   James   1.3   Allow reprint after orders ship (james03) */  
/* 2014-09-30   CSCHONG 1.4   SOS321616 (CS02)                          */  
/* 2014-10-07   CSCHONG 1.5   Revised the select scripts (CS03)         */  
/* 2014-11-13   CSCHONG 1.6   SOS325275 change field mapping (CS04)     */  
/* 2015-03-10   CSCHONG 1.7   SOS334999 (CS05)                          */  
/* 2016-04-06   CSCHONG 1.8   SOS367364 (CS06)                          */  
/* 2016-04-21   CSCHONG 1.9   minus 1 day from lpuserdefdate01 (CS07)   */  
/* 2017-08-04   CSCHONG 2.0   WMS-2462 - Add new field (CS08)           */  
/************************************************************************/    
CREATE PROC [dbo].[isp_TNTStorer_label] (     
   @c_dropid     NVARCHAR(20),     
   @c_StorerKey    NVARCHAR(15)   
   --@c_trackingNo   NVARCHAR(30)    
)     
AS    
BEGIN    
   SET NOCOUNT ON       
   SET QUOTED_IDENTIFIER OFF       
   SET ANSI_NULLS OFF       
   SET CONCAT_NULL_YIELDS_NULL OFF      
    
   DECLARE @n_continue        int,    
           @c_errmsg          NVARCHAR(255),    
           @b_success         int,    
           @n_err             int,    
           @n_starttcnt       int    
    
   DECLARE @n_NoOfCopy                      INT    
         , @c_CSDTrackingNo                 NVARCHAR(30)    
         , @c_ServiceTypeDescription        NVARCHAR(45)  
         , @n_CartonWeight                  float               
         , @c_FormCode                      NVARCHAR(10)   
         , @c_OrderDate                     NVARCHAR(12)  
         , @c_CSDOrderKey                   NVARCHAR(10)  
         , @c_AccountNo                     NVARCHAR(50)    
         , @c_SenderCompany                 NVARCHAR(30)   
         , @c_SenderAddress2                NVARCHAR(45)   
         , @c_SenderCity                    NVARCHAR(45)   
         , @c_SenderZip                     NVARCHAR(65)   
         , @c_SenderCountry                 NVARCHAR(30)   
         , @c_DeliveryCompany               NVARCHAR(45)   
         , @c_DeliveryAddress1              NVARCHAR(45)   
         , @c_DeliveryZip                   NVARCHAR(65)   
         , @c_DeliveryCountry               NVARCHAR(30)   
         , @c_DestinationZipCode            NVARCHAR(18)   
         , @c_RoutingCode                   NVARCHAR(10)   
         , @c_GroundBarcodeString           NVARCHAR(30)   
         , @c_Barcode                       NVARCHAR(30)   
         , @c_Terms                         NVARCHAR(30)  
         , @c_UCCLabelNo                    NVARCHAR(20)  
         , @c_PTSLOC                        NVARCHAR(20)  
         , @c_PriorityNotes                 NVARCHAR(30)         --CS02  
         , @c_Gender                        NVARCHAR(20)         --CS08  
    
   CREATE TABLE #TEMPTNTLABEL (    
           TrackingNo                    NVARCHAR(30) NULL    
         , ServiceTypeDescription        NVARCHAR(45) NULL     
         , CartonWeight                  float NULL              
         , FormCode                      NVARCHAR(10) NULL  
         , OrderDate                     NVARCHAR(12) NULL    
         , OrderKey                      NVARCHAR(10) NULL  
         , AccountNo                     NVARCHAR(50) NULL   
         , SenderCompany                 NVARCHAR(30) NULL  
         , SenderAddress2                NVARCHAR(45) NULL  
         , SenderCity                    NVARCHAR(45) NULL  
         , SenderZip                     NVARCHAR(65) NULL  
         , SenderCountry                 NVARCHAR(30) NULL  
         , DeliveryCompany               NVARCHAR(45) NULL  
         , DeliveryAddress1              NVARCHAR(45) NULL  
         , DeliveryZip                   NVARCHAR(65) NULL  
         , DeliveryCountry               NVARCHAR(30) NULL  
         , DestinationZipCode            NVARCHAR(18) NULL  
         , RoutingCode                   NVARCHAR(10) NULL  
         , GroundBarcodeString           NVARCHAR(30) NULL  
         , Barcode                       NVARCHAR(30) NULL  
         , Terms                         NVARCHAR(30) NULL  
         , UCCLabelNo                    NVARCHAR(20) NULL  
         , PTSLOC                        NVARCHAR(10) NULL  
         , PriorityNotes                 NVARCHAR(30) NULL   
         , Gender                        NVARCHAR(20) NULL           --CS08  
         )                                                                    
    
   SELECT @n_continue = 1, @n_starttcnt = @@TRANCOUNT     
    
   BEGIN TRAN     
       
   DECLARE cur_Sku CURSOR LOCAL FAST_FORWARD READ_ONLY FOR      
        
SELECT DISTINCT CSD.TrackingNumber,CSD.ServiceTypeDescription,CSD.CartonWeight,CSD.FormCode,--convert(nvarchar(12),LP.lpuserdefdate01,106),  --(CS04)  --(CS06)  
       --case when DATEPART(dw,LP.lpuserdefdate01) =6 THEN (convert(nvarchar(12),LP.lpuserdefdate01+1,106)) ELSE convert(nvarchar(12),LP.lpuserdefdate01,106) END ,  --CS06  
       convert(nvarchar(12),LP.lpuserdefdate01-1,106),--(CS07)  
       ORD.Orderkey,C.UDF03,'LF Logistics',F.Address2,F.city,(F.city+F.zip),F.country,  
      (ORD.Consigneekey+S.Company) as delivery_comp,S.Address1,(S.city + S.Zip),S.Country,  
       CSD.DestinationZipCode,CSD.RoutingCode,CSD.GroundBarcodeString,CSD.GroundBarcodeString,  
       --SSD.Terms, CSD.UCCLabelNo, -- (james01) --(CS06)  
   ISNULL(CSD.Servicecode,''), CSD.UCCLabelNo, -- (james01) --(CS06)  
       CASE WHEN S.SUSR5='PRIORITYHOLDSPS' THEN 'PRIORITY HOLD SPS' ELSE '' END   
      FROM cartonshipmentdetail CSD WITH (NOLOCK)  
      JOIN Orders ORD WITH (NOLOCK) ON ORD.Orderkey=CSD.Orderkey AND ORD.Storerkey=CSD.Storerkey   
     -- JOIN PACKHEADER WITH (NOLOCK) ON (ORD.Orderkey = PACKHEADER.Orderkey AND ORD.STORERKEY = PACKHEADER.STORERKEY)                 --(CS03)  
     -- JOIN PACKDETAIL WITH (NOLOCK) ON (PACKHEADER.PickSlipNo = PACKDETAIL.PickSlipNo AND PACKDETAIL.Labelno = CSD.UCCLabelNo)       --(CS03)  
     -- JOIN DROPID WITH (NOLOCK) ON (PACKDETAIL.DROPID = DROPID.DROPID AND DROPID.LoadKey = ORD.LOADKEY)  
     --  JOIN SKU WITH (NOLOCK) ON (PACKDETAIL.Storerkey = SKU.Storerkey AND PACKDETAIL.Sku = SKU.Sku)                                 --(CS03)  
      JOIN Facility F WITH (NOLOCK) ON F.facility = ORD.Facility  
--JOIN Storer S WITH (NOLOCK) ON S.Storerkey = CSD.Storerkey  
      JOIN Storer S WITH (NOLOCK) ON S.Storerkey = Ord.Consigneekey                                    --(CS01)  
     -- JOIN StorerSODefault SSD WITH (NOLOCK) ON SSD.Storerkey=Ord.Consigneekey                       --(CS06)  
      LEFT JOIN CODELKUP C (NOLOCK) ON C.Listname = 'WebService' AND c.code = 'TNTExpressLabelURL'  
      JOIN LOADPLAN LP (NOLOCK) ON LP.Loadkey=ORD.LoadKey          --(CS04)  
     -- WHERE PACKDETAIL.Dropid = @c_dropid                           --(CS03)  
     -- AND PACKDETAIL.Storerkey = @c_storerkey                       --(CS03)  
      WHERE CSD.UCCLabelNo = @c_dropid                                --(CS03)  
      AND CSD.Storerkey = @c_storerkey                                --(Cs03)  
      AND ORD.USERDEFINE01 = ''   
      --AND ORD.Status NOT IN ('9', 'CANC') (james03)  
     -- WHERE CSD.orderkey = @c_orderkey    
    --  AND CSD.Storerkey = @c_StorerKey    
    --  AND CSD.trackingNumber = @c_trackingNo  
    /*CS04 Start*/  
  
     UNION  
      SELECT DISTINCT CSD.TrackingNumber,CSD.ServiceTypeDescription,CSD.CartonWeight,CSD.FormCode,--convert(nvarchar(12),LP.lpuserdefdate01,106),  --(CS04)  --(CS06)  
  --case when DATEPART(dw,LP.lpuserdefdate01) =6 THEN (convert(nvarchar(12),LP.lpuserdefdate01+1,106)) ELSE convert(nvarchar(12),LP.lpuserdefdate01,106) END ,  --CS06   
  convert(nvarchar(12),LP.lpuserdefdate01-1,106),--(CS07)  
       ORD.Orderkey,C.UDF03,'LF Logistics',F.Address2,F.city,(F.city+F.zip),F.country,  
      (ORD.Consigneekey+S.Company) as delivery_comp,S.Address1,(S.city + S.Zip),S.Country,  
       CSD.DestinationZipCode,CSD.RoutingCode,CSD.GroundBarcodeString,CSD.GroundBarcodeString,  
       --SSD.Terms, CSD.UCCLabelNo, -- (james01)   --(CS06)  
   ISNULL(CSD.Servicecode,''), CSD.UCCLabelNo, -- (james01) --(CS06)  
       CASE WHEN S.SUSR5='PRIORITYHOLDSPS' THEN 'PRIORITY HOLD SPS' ELSE '' END   
      FROM cartonshipmentdetail CSD WITH (NOLOCK)  
      JOIN Orders ORD WITH (NOLOCK) ON ORD.Orderkey=CSD.Orderkey AND ORD.Storerkey=CSD.Storerkey  
      JOIN Facility F WITH (NOLOCK) ON F.facility = ORD.Facility  
      --JOIN Storer S WITH (NOLOCK) ON S.Storerkey = CSD.Storerkey  
      JOIN Storer S WITH (NOLOCK) ON S.Zip = ORD.C_Zip AND S.type='2'                                    --(CS01)  
     -- JOIN StorerSODefault SSD WITH (NOLOCK) ON SSD.Storerkey=S.storerkey                              --(CS06)  
      LEFT JOIN CODELKUP C (NOLOCK) ON C.Listname = 'WebService' AND c.code = 'TNTExpressLabelURL'  
      JOIN LOADPLAN LP (NOLOCK) ON LP.Loadkey=ORD.LoadKey    
      WHERE CSD.UCCLabelNo = @c_dropid                                  
      AND CSD.Storerkey = @c_storerkey   
      AND ORD.IncoTerm = 'CC'   
  /*CS04 End*/  
                
   OPEN cur_Sku      
   FETCH NEXT FROM cur_Sku INTO @c_CSDTrackingNo, @c_ServiceTypeDescription, @n_CartonWeight , @c_FormCode, @c_OrderDate                       
                              , @c_CSDOrderKey, @c_AccountNo , @c_SenderCompany, @c_SenderAddress2, @c_SenderCity                      
                              , @c_SenderZip, @c_SenderCountry, @c_DeliveryCompany, @c_DeliveryAddress1                
                              , @c_DeliveryZip, @c_DeliveryCountry, @c_DestinationZipCode              
                              , @c_RoutingCode, @c_GroundBarcodeString, @c_Barcode,@c_Terms, @c_UCCLabelNo ,@c_PriorityNotes  --CS02  
    
   WHILE @@FETCH_STATUS = 0      
   BEGIN        
    /*  IF ISNUMERIC(@c_NoOfCopy) = 0    
      BEGIN    
         SET @n_NoOfCopy = 0    
      END    
      ELSE    
      BEGIN    
         SET @n_NoOfCopy = CAST(@c_NoOfCopy AS INT)    
      END    
          
      WHILE @n_NoOfCopy > 0    
      BEGIN  */  
         -- (james02)  
         SELECT TOP 1 @c_PTSLOC = CASE WHEN TD.TaskType = 'SPK' THEN TD.ToLoc ELSE PD.LOC END   
         FROM dbo.PickDetail PD WITH (NOLOCK)   
         JOIN dbo.TaskDetail TD WITH (NOLOCK) ON PD.TaskDetailKey = TD.TaskDetailKey  
     WHERE PD.StorerKey = @c_StorerKey  
         AND   PD.ALTSKU = @c_UCCLabelNo  
         AND   PD.Status >= '5'  
           
         /*Cs08 start*/  
         SET @c_Gender=''  
           
         SELECT TOP 1 @c_Gender = StoreGroup  
         FROM StoreToLocDetail (NOLOCK)  
         WHERE loc = @c_PTSLOC  
           
         /*CS08 End*/  
           
           
         INSERT INTO #TEMPTNTLABEL     
            (TrackingNo, ServiceTypeDescription, CartonWeight, FormCode, OrderDate                          
         , OrderKey , AccountNo, SenderCompany, SenderAddress2, SenderCity, SenderZip                       
         , SenderCountry, DeliveryCompany, DeliveryAddress1, DeliveryZip                      
         , DeliveryCountry, DestinationZipCode, RoutingCode, GroundBarcodeString,Barcode,Terms  
         , UCCLabelNo, PTSLOC, PriorityNotes,Gender)  --CS02          --CS08                                                 
         VALUES    
            (@c_CSDTrackingNo, @c_ServiceTypeDescription, @n_CartonWeight , @c_FormCode, @c_OrderDate                       
         , @c_CSDOrderKey , @c_AccountNo , @c_SenderCompany, @c_SenderAddress2, @c_SenderCity                      
         , @c_SenderZip, @c_SenderCountry, @c_DeliveryCompany, @c_DeliveryAddress1                
         , @c_DeliveryZip, @c_DeliveryCountry, @c_DestinationZipCode              
         , @c_RoutingCode, @c_GroundBarcodeString, @c_Barcode,@c_Terms, @c_UCCLabelNo, @c_PTSLOC ,@c_PriorityNotes,@c_Gender)   --CS02 --CS08  
          
         SET @n_err = @@ERROR    
         IF @n_err <> 0    
         BEGIN    
            SELECT @n_continue = 3    
            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 63104       
          
            SELECT @c_errmsg = 'NSQL'+CONVERT(char(5),@n_err)+': Insert #TEMPLABEL Failed. ' +     
                               ' (isp_SKULabel01)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '    
            GOTO EXIT_SP    
         END    
          
         --SET @n_NoOfCopy = @n_NoOfCopy - 1    
     -- END    
          
      FETCH NEXT FROM cur_Sku INTO @c_CSDTrackingNo, @c_ServiceTypeDescription, @n_CartonWeight , @c_FormCode, @c_OrderDate                       
                                 , @c_CSDOrderKey, @c_AccountNo , @c_SenderCompany, @c_SenderAddress2, @c_SenderCity                      
                                 , @c_SenderZip, @c_SenderCountry, @c_DeliveryCompany, @c_DeliveryAddress1                
                                 , @c_DeliveryZip, @c_DeliveryCountry, @c_DestinationZipCode              
                                 , @c_RoutingCode, @c_GroundBarcodeString , @c_Barcode ,@c_Terms, @c_UCCLabelNo  ,@c_PriorityNotes   --CS02  
   END    
   CLOSE cur_Sku     
   DEALLOCATE cur_Sku                                               
         
   SELECT TrackingNo, ServiceTypeDescription, CartonWeight, FormCode, OrderDate                          
         , OrderKey, AccountNo, SenderCompany, SenderAddress2, SenderCity, SenderZip                       
         , SenderCountry, DeliveryCompany, DeliveryAddress1, DeliveryZip                      
         , DeliveryCountry, DestinationZipCode, RoutingCode, GroundBarcodeString, substring(Barcode,1,10)   
         ,Terms, UCCLabelNo, PTSLOC , PriorityNotes,Gender        --CS02  --CS08  
   FROM #TEMPTNTLABEL    
   --ORDER BY Sku    
    
   DROP TABLE #TEMPTNTLABEL    
    
   EXIT_SP:     
   IF @n_continue = 3    
   BEGIN    
      WHILE @@TRANCOUNT > @n_starttcnt    
      ROLLBACK TRAN    
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'isp_TNTStorer_label'    
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012    
      RETURN    
   END    
   ELSE    
   BEGIN    
      /* Error Did Not Occur , Return Normally */    
      WHILE @@TRANCOUNT > @n_starttcnt    
         COMMIT TRAN    
      RETURN    
   END    
    
END    
  
  

GO