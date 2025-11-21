SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/******************************************************************************/              
/* Store Procedure: isp_Mbol_Manifestdetails_06                               */              
/* Creation Date: 05-MAR-2018                                                 */              
/* Copyright: IDS                                                             */              
/* Written by: CSCHONG                                                        */              
/*                                                                            */              
/* Purpose: WMS-4095-CN_PVH_POD_New                                           */  
/*                                                                            */              
/*                                                                            */              
/* Called By:  r_dw_manifest_detail_06.srd                                    */              
/*                                                                            */              
/* PVCS Version: 1.0                                                          */              
/*                                                                            */              
/* Version: 1.0                                                               */              
/*                                                                            */              
/* Data Modifications:                                                        */              
/*                                                                            */              
/* Updates:                                                                   */              
/* Date         Author    Ver.  Purposes                                      */     
/* 28-AUG-2018  CSCHONG   1.1   WMS-5698 add new report type (CS01)           */
/* 15-OCT-2018  SPChin    1.2   INC0427946 - Bug Fixed                        */
/* 25-Feb-2020  WLChooi   1.3   WMS-12074 - Add barcode and modify some column*/
/*                              mapping (WL01)                                */
/* 21-Feb-2023  Mingle    1.4   WMS-21828 - Modify logic(ML01)                */
/* 14-MAR-2023  CHONGCS   1.5   Devops Scripts Combine & WMS-21930 (CS02)     */
/******************************************************************************/     
  
CREATE   PROC [dbo].[isp_Mbol_Manifestdetails_06]             
       (@c_Mbolkey      NVARCHAR(10)
       ,@c_type         NVARCHAR(5) = 'H'
       ,@c_RptType      NVARCHAR(5) = ''
       ,@c_consigneekey NVARCHAR(20) = '')              
AS            
BEGIN            
   SET NOCOUNT ON            
   SET ANSI_WARNINGS OFF            
   SET QUOTED_IDENTIFIER OFF            
   SET CONCAT_NULL_YIELDS_NULL OFF    
  
   DECLARE @c_getmbolkey       NVARCHAR(10)
        -- ,@c_consigneekey     NVARCHAR(45)
          ,@c_storerkey        NVARCHAR(10)
          ,@n_CntRec           INT
          ,@n_maxline          INT
          ,@n_Rowno            INT
          ,@n_getRowno         INT
          ,@c_Userdefine10     NVARCHAR(10) = ''   --WL01
          ,@n_ShowMBOLBarcode  INT = 0             --WL01
          ,@n_ShowMBOLQRCode   INT = 0             --WL01
          ,@c_c1code2          NVARCHAR(10)        --ML01  
  
   SET @c_storerkey = ''
   SET @n_CntRec = 1
   SET @n_maxline = 20
   SET @n_Rowno = 1
   
   SET @c_getmbolkey = ''
   -- SET @c_consigneekey = ''
    
   SELECT TOP 1 @c_storerkey  = OH.storerkey
   FROM ORDERS OH WITH (NOLOCK)  
   WHERE OH.mbolkey = @c_Mbolkey     
   
   --WL01 START
   SELECT @c_Userdefine10 = MIN(OH.Userdefine10)
   FROM ORDERS OH (NOLOCK) 
   WHERE OH.MBOLKey = @c_Mbolkey

   SELECT TOP 1 @c_c1code2  = ISNULL(cl.code2,'')
   FROM codelkup cl WITH (NOLOCK)  
   WHERE cl.LISTNAME = 'PVHBRAND' AND cl.long = @c_Userdefine10 AND cl.storerkey = @c_storerkey --ML01

   SELECT @n_ShowMBOLQRCode    = ISNULL(MAX(CASE WHEN Code = 'ShowMBOLQRCode' THEN 1 ELSE 0 END),0)    
        , @n_ShowMBOLBarcode   = ISNULL(MAX(CASE WHEN Code = 'ShowMBOLBarcode' THEN 1 ELSE 0 END),0)   
   FROM CODELKUP WITH (NOLOCK)    
   WHERE ListName = 'REPORTCFG'    
   AND   Storerkey= @c_storerkey    
   AND   Long = 'r_dw_manifest_detail_06'    
   AND   ISNULL(Short,'') <> 'N' 

   --WL01 END 
         
   IF @c_type = 'H' GOTO TYPE_H
   IF @c_type = 'D' GOTO TYPE_D
  
   TYPE_H:
  
   CREATE TABLE #TEMPMNFTBLH06
   (mbolkey         NVARCHAR(10) NULL,
    ReportType      NVARCHAR(5)  NULL,
    Consigneekey    NVARCHAR(20) NULL)
     
   INSERT INTO #TEMPMNFTBLH06
   (
      mbolkey,
      ReportType,
      Consigneekey
   ) 
   SELECT OH.mbolkey,CASE WHEN MIN(C.UDF04) = 'W' THEN 'WS' 
                          WHEN MIN(C.UDF04) = 'R' THEN 'RS' 
                          ELSE 'RW' END,
          OH.Consigneekey
   FROM ORDERS  OH WITH (NOLOCK) 
   JOIN codelkup C WITH (NOLOCK) ON C.listname = 'ordergroup' AND OH.ordergroup = C.code AND OH.storerkey = C.storerkey 
   WHERE OH.storerkey = @c_storerkey 
   AND OH.mbolkey = @c_mbolkey  
   AND OH.status IN ('5','9')
   GROUP BY OH.mbolkey , OH.Consigneekey
  
   SELECT *,@n_ShowMBOLBarcode AS ShowMBOLBarcode FROM #TEMPMNFTBLH06  --WL01
   DROP TABLE #TEMPMNFTBLH06
   GOTO QUIT;
   

   TYPE_D:
   CREATE TABLE #TEMPMNFTBLD06
   (mbolkey         NVARCHAR(10) NULL,
    Storerkey       NVARCHAR(15) NULL,
    Consigneekey    NVARCHAR(20) NULL,
    c_company       NVARCHAR(45) NULL,
    c_address1      NVARCHAR(45) NULL,
    c_address2      NVARCHAR(45) NULL,
    c_contact1      NVARCHAR(90) NULL,      --CS02
    c_phone1        NVARCHAR(90) NULL,      --CS02
    STSecondary     NVARCHAR(30) NULL,
    LoadKey         NVARCHAR(20) NULL,
    qty             INT NULL,
    Notes1          NVARCHAR(4000) NULL,
    Orderkey        NVARCHAR(10) NULL,
    Brand           NVARCHAR(80) NULL,
    PCarton         INT ,
    SUSR2           INT,
    DELdate         NVARCHAR(10) NULL ,
    shipdate        NVARCHAR(10) NULL,
    RecLine         INT,
    RptTitle        NVARCHAR(50) NULL,
    STContact1      NVARCHAR(45) NULL,      --CS02
    STContact2      NVARCHAR(45) NULL       --CS02
   )

  --select @c_RptType '@c_RptType'

   IF @c_RptType='WS'
   BEGIN
      INSERT INTO #TEMPMNFTBLD06
      (mbolkey,Storerkey,Consigneekey,c_company,    
       c_address1,c_address2,c_contact1,c_phone1,STSecondary,    
       LoadKey,Qty,Notes1,Orderkey,Brand,    
       PCarton,SUSR2,DELdate,shipdate,RecLine,RptTitle,STContact1,STContact2)        --CS02
      SELECT MBOL.Mbolkey,
             ORDERS.Storerkey,  
             ORDERS.Consigneekey,   
             ORDERS.C_Company,   
             ORDERS.C_Address1,   
             ORDERS.C_Address2,      
             ISNULL(ORDERS.C_contact1,''),   
             ISNULL(ORDERS.C_Phone1,''),   
             '' AS STSecondary,  
             ORDERS.externorderkey ,
             QTY =  (SELECT sum(PD.qty) FROM packheader as PH  WITH (NOLOCK)
                     JOIN Packdetail as PD WITH (nolock) on PH.pickslipno = PD.pickslipno
                     WHERE PH.orderkey = ORDERS.orderkey),
             notes1= '',
             ORDERS.Orderkey,     
             Brand = (SELECT MAX(SKU.BUSR6) FROM PickDetail PD WITH (NOLOCK)
                      JOIN   SKU SKU WITH (NOLOCK) on PD.Storerkey = SKU.Storerkey and PD.SKU = SKU.SKU
                      where PD.Orderkey = ORDERS.Orderkey), 
             PCarton = (SELECT COUNT(DISTINCT PD.labelno) 
                        FROM Packheader as PH WITH (NOLOCK)
                        JOIN Packdetail as PD WITH (NOLOCK) ON PH.pickslipno = PD.pickslipno
                        WHERE PH.orderkey = ORDERS.orderkey)   , 
             0 AS susr2,
             '' AS deliverydate,
             CASE WHEN MBOL.shipdate is null THEN CONVERT(NVARCHAR(10),getdate(),121) ELSE CONVERT(NVARCHAR(10),MBOL.shipdate,121) end AS ShipDate,
             row_number() over( PARTITION BY MBOL.Mbolkey,ORDERS.Consigneekey order by MBOL.Mbolkey,ORDERS.Consigneekey,ORDERS.externorderkey,ORDERS.Orderkey) as RecLine,
             --RptTitle = ISNULL(C.notes,'')
             RptTitle = CASE WHEN ISNULL(C.UDF01,'') = @c_Userdefine10 AND ISNULL(C.Code2,'') <> '' THEN ISNULL(C.Code2,'') ELSE ISNULL(C.notes,'') END,  --WL01
             '',''                                                --CS02
      FROM ORDERS WITH (NOLOCK)    
      JOIN MBOL WITH (NOLOCK)   ON ( ORDERS.Mbolkey = MBOL.Mbolkey )   
      LEFT JOIN CODELKUP C WITH (NOLOCK) ON C.listname='PVHPOD' AND C.CODE='01' AND C.Storerkey = ORDERS.StorerKey       
      WHERE ( MBOL.Mbolkey = @c_Mbolkey ) 
      AND ORDERS.StorerKey = @c_storerkey
      AND ORDERS.status in ('5','9')
      AND ORDERS.Consigneekey= @c_consigneekey
      ORDER BY MBOL.MbolKey,ORDERS.Consigneekey,ORDERS.LoadKey,ORDERS.OrderKey
   END
   ELSE IF  @c_RptType='RS'
   BEGIN
      INSERT INTO #TEMPMNFTBLD06
      (mbolkey,Storerkey,Consigneekey,c_company,    
       c_address1,c_address2,c_contact1,c_phone1,STSecondary,    
       LoadKey,Qty,Notes1,Orderkey,Brand,    
       PCarton,SUSR2,DELdate,shipdate,RecLine,RptTitle,STContact1,STContact2)   --CS02
      SELECT MBOL.Mbolkey,
             ORDERS.Storerkey,  
             ORDERS.Consigneekey,   
             CASE WHEN ISNULL(C1.code2,'') = 'SAP' THEN STORER.company ELSE ORDERS.C_Company END,            --CS02   S
             CASE WHEN ISNULL(C1.code2,'') = 'SAP' THEN STORER.Address2 ELSE ORDERS.C_Address1 END,   
             CASE WHEN ISNULL(C1.code2,'') = 'SAP' THEN STORER.Address1 ELSE ORDERS.C_Address2 END,      
             CASE WHEN ISNULL(C1.code2,'') = 'SAP' THEN ISNULL(STORER.contact1,'') + ' ' + ISNULL(STORER.contact2,'') ELSE ORDERS.C_contact1 END,   
             CASE WHEN ISNULL(C1.code2,'') = 'SAP' THEN ISNULL(STORER.phone1,'') + ' ' + ISNULL(STORER.phone2,'') ELSE ORDERS.C_Phone1 END,                   --CS02 E
             STORER.Secondary AS STSecondary,  
             ORDERS.loadkey,
             QTY =  (SELECT sum(PD.qty) FROM packheader as PH  WITH (NOLOCK)
                     JOIN Packdetail as PD WITH (nolock) on PH.pickslipno = PD.pickslipno
                     WHERE PH.loadkey = ORDERS.loadkey),
             notes1= CASE WHEN ISNULL(C1.code2,'') = 'SAP' THEN ISNULL(STORER.address3,'') ELSE STORER.Notes1  END,    --Cs02
             '',     
             Brand = PD.brand,                                                                        --CS02 S
             --Brand = (SELECT MAX(SKU.BUSR6) 
             --         FROM PickDetail PD WITH (NOLOCK) 
             --         JOIN SKU SKU WITH (NOLOCK) ON PD.Storerkey = SKU.Storerkey AND PD.SKU = SKU.SKU 
             --         WHERE PD.Orderkey = ORDERS.Orderkey), --ML01                                  --CS02 E
             PCarton =  (SELECT COUNT(DISTINCT PD.labelno)  
                         FROM Packheader AS PH WITH (NOLOCK)
                         JOIN Packdetail AS PD WITH (NOLOCK) ON PH.pickslipno = PD.pickslipno
                         WHERE PH.loadkey = ORDERS.loadkey), 
             SUSR2=CASE WHEN ISNUMERIC(STORER.susr2) = 1 THEN CAST(STORER.susr2 AS INT) ELSE 0 END,
             '' AS deliverydate,
             shipDate =  MAX(CASE WHEN MBOL.shipdate is null THEN CONVERT(NVARCHAR(10),getdate(),121) ELSE CONVERT(NVARCHAR(10),MBOL.shipdate,121) END),
             ROW_NUMBER() OVER( PARTITION BY MBOL.Mbolkey,ORDERS.Consigneekey ORDER BY MBOL.Mbolkey,ORDERS.Consigneekey,ORDERS.loadkey) AS RecLine,
             --RptTitle = ISNULL(C.notes,'')
             RptTitle = CASE WHEN ISNULL(C.UDF01,'') = @c_Userdefine10 AND ISNULL(C.Code2,'') <> '' THEN ISNULL(C.Code2,'') ELSE ISNULL(C.notes,'') END,  --WL01
             STContact1 = ISNULL(STORER.phone1,''),                                                --CS02
             STContact2 = ISNULL(STORER.phone2,'')                                                 --CS02    
      FROM ORDERS WITH (NOLOCK)   
      --JOIN STORER WITH (NOLOCK) ON ( STORER.StorerKey = 'PVH-'+ORDERS.consigneekey )   
      JOIN STORER WITH (NOLOCK) ON ( STORER.StorerKey = CASE WHEN ISNULL(@c_c1code2,'') = 'SAP' THEN 'PVH-'+ORDERS.consigneekey ELSE 'PVH'+ORDERS.consigneekey END) --ML01
      JOIN MBOL WITH (NOLOCK)   ON ( ORDERS.Mbolkey = MBOL.Mbolkey )     
      LEFT JOIN CODELKUP C WITH (NOLOCK) ON C.listname='PVHPOD' AND C.CODE='01' AND C.Storerkey = ORDERS.StorerKey         
      LEFT JOIN CODELKUP C1 WITH (NOLOCK) ON C1.listname='PVHBRAND' AND C1.Long=ORDERS.USerDefine10 AND C1.Storerkey = ORDERS.StorerKey         --CS02
      CROSS APPLY (SELECT MAX(SKU.BUSR6) AS brand                                                        --CS02 S
                      FROM PickDetail PD WITH (NOLOCK) 
                      JOIN SKU SKU WITH (NOLOCK) ON PD.Storerkey = SKU.Storerkey AND PD.SKU = SKU.SKU 
                      WHERE PD.Orderkey = ORDERS.Orderkey) AS PD 
      WHERE ( MBOL.Mbolkey = @c_Mbolkey ) 
      AND ORDERS.Storerkey = @c_storerkey
      AND ORDERS.status IN ('5','9') 
      AND ORDERS.Consigneekey= @c_consigneekey
      GROUP BY  MBOL.Mbolkey,
                ORDERS.Storerkey,  
                ORDERS.Consigneekey,   
                --ORDERS.C_Company,      --CS02 S
                --ORDERS.C_Address1,   
                --ORDERS.C_Address2,     
                --ORDERS.C_contact1,   
                --ORDERS.C_Phone1,  
                CASE WHEN ISNULL(C1.code2,'') = 'SAP' THEN STORER.company ELSE ORDERS.C_Company END,          
                CASE WHEN ISNULL(C1.code2,'') = 'SAP' THEN STORER.Address2 ELSE ORDERS.C_Address1 END,   
                CASE WHEN ISNULL(C1.code2,'') = 'SAP' THEN STORER.Address1 ELSE ORDERS.C_Address2 END,      
                CASE WHEN ISNULL(C1.code2,'') = 'SAP' THEN ISNULL(STORER.contact1,'') + ' ' + ISNULL(STORER.contact2,'') ELSE ORDERS.C_contact1 END,   
                CASE WHEN ISNULL(C1.code2,'') = 'SAP' THEN ISNULL(STORER.phone1,'') + ' ' + ISNULL(STORER.phone2,'') ELSE ORDERS.C_Phone1 END,                   --CS02 E
                Storer.Secondary,
                ORDERS.loadkey,
                --STORER.Notes1,
                CASE WHEN ISNULL(C1.code2,'') = 'SAP' THEN ISNULL(STORER.address3,'') ELSE STORER.Notes1  END,                                              --CS02
                --ORDERS.orderkey,                                                                                                                          --CS02
                --ORDERS.deliverynote,
                CASE WHEN ISNUMERIC(STORER.susr2) = 1 THEN CAST(STORER.susr2 AS INT) ELSE 0 END,
                --ISNULL(C.notes,'')
                CASE WHEN ISNULL(C.UDF01,'') = @c_Userdefine10 AND ISNULL(C.Code2,'') <> '' THEN ISNULL(C.Code2,'') ELSE ISNULL(C.notes,'') END , --WL01
                ISNULL(STORER.phone1,''),ISNULL(STORER.phone2,''),ISNULL(C1.code2,'') , PD.brand               --CS02
      ORDER BY MBOL.Mbolkey,ORDERS.Consigneekey,ORDERS.loadkey
   END
  --CS01 Start
  ELSE IF  @c_RptType='RW'
  BEGIN
      INSERT INTO #TEMPMNFTBLD06
      (
       mbolkey,Storerkey,Consigneekey,c_company,    
       c_address1,c_address2,c_contact1,c_phone1,STSecondary,    
       LoadKey,Qty,Notes1,Orderkey,Brand,    
       PCarton,SUSR2,DELdate,shipdate,RecLine,RptTitle,STContact1,STContact2)      --CS02
      SELECT MBOL.Mbolkey,
             ORDERS.Storerkey,  
             ORDERS.Consigneekey,   
             CASE WHEN ISNULL(C1.code2,'') = 'SAP' THEN STORER.company ELSE ORDERS.C_Company END,            --CS02   S
             CASE WHEN ISNULL(C1.code2,'') = 'SAP' THEN STORER.Address1 ELSE ORDERS.C_Address1 END,   
             CASE WHEN ISNULL(C1.code2,'') = 'SAP' THEN STORER.Address2 ELSE ORDERS.C_Address2 END,      
             CASE WHEN ISNULL(C1.code2,'') = 'SAP' THEN ISNULL(STORER.contact1,'') + ' ' + ISNULL(STORER.contact2,'') ELSE ORDERS.C_contact1 END,   
             CASE WHEN ISNULL(C1.code2,'') = 'SAP' THEN ISNULL(STORER.phone1,'') + ' ' + ISNULL(STORER.phone2,'') ELSE ORDERS.C_Phone1 END,                   --CS02 E      
             STORER.Secondary AS STSecondary,  
             ORDERS.externorderkey,
             QTY =  (SELECT SUM(PD.qty) FROM packheader AS PH  WITH (NOLOCK)
                     JOIN Packdetail AS PD WITH (NOLOCK) ON PH.pickslipno = PD.pickslipno
                     WHERE PH.Orderkey = ORDERS.Orderkey),      --INC0427946
             notes1=CASE WHEN ISNULL(C1.code2,'') = 'SAP' THEN ISNULL(STORER.address3,'') ELSE STORER.Notes1  END,                                      --CS02
             ORDERS.orderkey,     
             --Brand = ORDERS.deliverynote, 
             Brand = (SELECT MAX(SKU.BUSR6) 
                      FROM PickDetail PD WITH (NOLOCK) 
                      JOIN SKU SKU WITH (NOLOCK) ON PD.Storerkey = SKU.Storerkey AND PD.SKU = SKU.SKU 
                      WHERE PD.Orderkey = ORDERS.Orderkey), --ML01
             PCarton =  (SELECT COUNT(DISTINCT PD.labelno) 
                         FROM Packheader AS PH WITH (NOLOCK)
                         JOIN Packdetail AS PD WITH (NOLOCK) ON PH.pickslipno = PD.pickslipno
                         WHERE PH.Orderkey = ORDERS.Orderkey),  --INC0427946 
             SUSR2=CASE WHEN ISNUMERIC(STORER.susr2) = 1 THEN CAST(STORER.susr2 AS INT) ELSE 0 END,
             '' AS deliverydate,
             shipDate =  MAX(CASE WHEN MBOL.shipdate IS NULL THEN CONVERT(NVARCHAR(10),GETDATE(),121) ELSE CONVERT(NVARCHAR(10),MBOL.shipdate,121) END),
             ROW_NUMBER() OVER( PARTITION BY MBOL.Mbolkey,ORDERS.Consigneekey ORDER BY MBOL.Mbolkey,ORDERS.Consigneekey,ORDERS.loadkey) AS RecLine,
             --RptTitle = ISNULL(C.notes,'')
             RptTitle = CASE WHEN ISNULL(C.UDF01,'') = @c_Userdefine10 AND ISNULL(C.Code2,'') <> '' THEN ISNULL(C.Code2,'') ELSE ISNULL(C.notes,'') END,  --WL01
             STContact1 = ISNULL(STORER.phone1,''),                                                --CS02
             STContact2 = ISNULL(STORER.phone2,'')                                                 --CS02  
      FROM ORDERS WITH (NOLOCK)   
      --JOIN STORER WITH (NOLOCK) ON  ( STORER.StorerKey = 'PVH'+ORDERS.consigneekey ) 
      JOIN STORER WITH (NOLOCK) ON ( STORER.StorerKey = CASE WHEN ISNULL(@c_c1code2,'') = 'SAP' THEN 'PVH-'+ORDERS.consigneekey ELSE 'PVH'+ORDERS.consigneekey END) --ML01
      JOIN MBOL WITH (NOLOCK)   ON ( ORDERS.Mbolkey = MBOL.Mbolkey )     
      LEFT JOIN CODELKUP C WITH (NOLOCK) ON C.listname='PVHPOD' AND C.CODE='01' AND C.Storerkey = ORDERS.StorerKey   
      LEFT JOIN CODELKUP C1 WITH (NOLOCK) ON C1.listname='PVHBRAND' AND C1.Long=ORDERS.USerDefine10 AND C1.Storerkey = ORDERS.StorerKey         --CS02
      WHERE ( MBOL.Mbolkey = @c_Mbolkey ) 
      AND ORDERS.Storerkey = @c_storerkey
      AND ORDERS.status IN ('5','9') 
      AND ORDERS.Consigneekey= @c_consigneekey
      GROUP BY  MBOL.Mbolkey,
                ORDERS.Storerkey,  
                ORDERS.Consigneekey,   
                --ORDERS.C_Company,                                                                  --CS02 S
                --ORDERS.C_Address1,   
                --ORDERS.C_Address2,     
                --ORDERS.C_contact1,   
                --ORDERS.C_Phone1,  
                CASE WHEN ISNULL(C1.code2,'') = 'SAP' THEN STORER.company ELSE ORDERS.C_Company END,           
                CASE WHEN ISNULL(C1.code2,'') = 'SAP' THEN STORER.Address1 ELSE ORDERS.C_Address1 END,   
                CASE WHEN ISNULL(C1.code2,'') = 'SAP' THEN STORER.Address2 ELSE ORDERS.C_Address2 END,      
                CASE WHEN ISNULL(C1.code2,'') = 'SAP' THEN ISNULL(STORER.contact1,'') + ' ' + ISNULL(STORER.contact2,'') ELSE ORDERS.C_contact1 END,   
                CASE WHEN ISNULL(C1.code2,'') = 'SAP' THEN ISNULL(STORER.phone1,'') + ' ' + ISNULL(STORER.phone2,'') ELSE ORDERS.C_Phone1 END,                   --CS02 E
                Storer.Secondary,
                ORDERS.externorderkey,
                --STORER.Notes1,
                CASE WHEN ISNULL(C1.code2,'') = 'SAP' THEN ISNULL(STORER.address3,'') ELSE STORER.Notes1  END,                                              --CS02
                ORDERS.orderkey, 
                --ORDERS.deliverynote,
                CASE WHEN ISNUMERIC(STORER.susr2) = 1 THEN CAST(STORER.susr2 AS INT) ELSE 0 END,
                --ISNULL(C.notes,'')
                CASE WHEN ISNULL(C.UDF01,'') = @c_Userdefine10 AND ISNULL(C.Code2,'') <> '' THEN ISNULL(C.Code2,'') ELSE ISNULL(C.notes,'') END,  --WL01
                ORDERS.loadkey,ISNULL(STORER.phone1,''),ISNULL(STORER.phone2,'')                                      --CS02
      ORDER BY MBOL.Mbolkey,ORDERS.Consigneekey,ORDERS.orderkey 
   END
  --CS01 End

  
/*DECLARE CUR_RESULT CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
   SELECT DISTINCT mbolkey,Consigneekey ,MAX(RecLine)  
   FROM  #TEMPMNFTBLD06
   WHERE mbolkey = @c_Mbolkey
   GROUP BY mbolkey,Consigneekey
   ORDER BY mbolkey,Consigneekey
  
   OPEN CUR_RESULT   
     
   FETCH NEXT FROM CUR_RESULT INTO @c_getmbolkey,@c_consigneekey ,@n_Rowno   
     
   WHILE @@FETCH_STATUS <> -1  
   BEGIN   

   SET @n_getRowno = @n_Rowno
  
  --SELECT @c_getmbolkey '@c_getmbolkey',@c_consigneekey '@c_consigneekey',@n_Rowno '@n_Rowno'
  --* FROM #TEMPMNFTBLD06
 ---- group by mbolkey,Consigneekey
 -- ORDER BY mbolkey,Consigneekey
 -- GOTO QUIT
  
  SELECT @n_CntRec = COUNT(1)--,@n_Rowno = MAX(RecLine)
  FROM #TEMPMNFTBLD06
  WHERE mbolkey = @c_getMbolkey
  AND Consigneekey=@c_consigneekey
  
  --SELECT @n_CntRec '@n_CntRec'
  
  WHILE @n_CntRec < @n_maxline
  BEGIN
   
   --SET @n_getRowno= @n_getRowno + 1
   
   INSERT INTO #TEMPMNFTBLD06  (
    mbolkey,Storerkey,Consigneekey,c_company,    
    c_address1,c_address2,c_contact1,c_phone1,STSecondary,    
    LoadKey,Qty,Notes1,Orderkey,Brand,    
    PCarton,SUSR2,DELdate,shipdate,RecLine,RptTitle)
    SELECT TOP 1 
    mbolkey,Storerkey,Consigneekey,c_company,    
    c_address1,c_address2,c_contact1,c_phone1,STSecondary,    
    '',0,'','','',    
    0,0,DELdate,shipdate,(RecLine+1),''
    FROM #TEMPMNFTBLD06 AS t
    WHERE mbolkey = @c_Mbolkey
    AND t.Consigneekey =@c_consigneekey
    ORDER BY recline desc---mbolkey,Consigneekey,loadkey,orderkey
    
    SET @n_CntRec = @n_CntRec + 1  
    
  END
  
  --SET @n_Rowno = 1
  
   FETCH NEXT FROM CUR_RESULT INTO @c_getmbolkey,@c_consigneekey ,@n_Rowno      
     
   END  
   */
   
   SELECT DISTINCT mbolkey,Storerkey,Consigneekey,c_company,    
          c_address1,c_address2,c_contact1,c_phone1,STSecondary,    
          LoadKey,Qty,Notes1,Orderkey,Brand,    
          --PCarton,SUSR2,CONVERT(NVARCHAR(10),DATEADD(DAY, susr2, shipdate),121) AS deldate, --remove deldate logic ML01
          PCarton,SUSR2,'' AS deldate,
          shipdate,RecLine,RptTitle,@n_ShowMBOLQRCode,STContact1,STContact2  --WL01    --CS02
   FROM #TEMPMNFTBLD06  
   ORDER BY mbolkey, Consigneekey, RecLine, loadkey, orderkey 
               
END

QUIT:


GO