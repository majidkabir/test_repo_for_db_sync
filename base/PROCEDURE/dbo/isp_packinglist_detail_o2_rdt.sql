SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/    
/* Store Procedure:  isp_packinglist_detail_O2_rdt                      */
/* Creation Date: 25-Nov-2020                                           */
/* Copyright: LFL                                                       */
/* Written by: WLChooi                                                  */ 
/*                                                                      */    
/* Purpose: WMS-15247 - O2 Packing List                                 */
/*                                                                      */    
/* Input Parameters: PickSlipNo, RefNo                                  */    
/*                                                                      */    
/* Output Parameters:                                                   */    
/*                                                                      */    
/* Usage:                                                               */    
/*                                                                      */    
/* Called By:  r_dw_packing_list_detail_o2_rdt                          */    
/*                                                                      */    
/* GitLab Version: 1.0                                                  */    
/*                                                                      */    
/* Version: 5.4                                                         */    
/*                                                                      */    
/* Data Modifications:                                                  */    
/*                                                                      */    
/* Updates:                                                             */    
/* Date         Author   Ver  Purposes                                  */    
/************************************************************************/  

CREATE PROC [dbo].[isp_packinglist_detail_O2_rdt] (
   @c_pickslipno              NVARCHAR( 10),
   @c_RefNo                   NVARCHAR(20) = ''
)
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  @c_Zone               NVARCHAR(30)
           ,@c_storerkey          NVARCHAR(20)
          -- , @c_Zone            NVARCHAR(30)
           ,@n_cntRefno           INT         
           ,@c_site               NVARCHAR(30)
           ,@c_FUserdefine12      NVARCHAR(20)

   DECLARE @n_NewCartonNo      	INT							
         , @n_OriginalCartonNo 	INT

   SELECT @c_storerkey = PH.Storerkey
   FROM PACKHEADER PH (NOLOCK)
   WHERE PH.PickSlipNo=@c_pickslipno

   SET @c_zone = ''

   SELECT @c_zone = C.code2
   FROM CODELKUP C WITH (NOLOCK)
   WHERE C.LISTNAME='REPORTCFG'
   AND C.Storerkey = @c_storerkey
   AND C.Code = 'PackListFilterByRefNo'
   AND C.Long = 'r_dw_packing_list_detail_o2'
   
   SELECT TOP 1 @c_FUserdefine12 = F.Userdefine12
   FROM FACILITY F (NOLOCK)
   JOIN ORDERS OH (NOLOCK) ON OH.Facility = F.Facility
   JOIN LOADPLANDETAIL LPD (NOLOCK) ON LPD.OrderKey = OH.OrderKey
   JOIN PACKHEADER PH (NOLOCK) ON PH.LoadKey = LPD.LoadKey
   WHERE PH.PickSlipNo = @c_Pickslipno

   CREATE TABLE #TMP_PACKDET
   (    RowRef            INT NOT NULL IDENTITY(1,1) PRIMARY KEY
      , Orderkey          NVARCHAR(10)   NULL
      , ExternOrderkey    NVARCHAR(50)   NULL
      , ConsigneeKey      NVARCHAR(15)   NULL
      , C_Contact1        NVARCHAR(30)   NULL
      , C_Address1        NVARCHAR(45)   NULL
      , C_Address2        NVARCHAR(45)   NULL
      , C_Address3        NVARCHAR(45)   NULL
      , C_Address4        NVARCHAR(45)   NULL
      , C_Phone1          NVARCHAR(18)   NULL
      , DeliveryDate      DATETIME       NULL
      , SKU               NVARCHAR(20)   NULL
      , CartonNo          INT            NULL
      , PickSlipNo        NVARCHAR(10)   NULL
      , LoadKey           NVARCHAR(10)   NULL
      , PackQty           INT            NULL
      , BuyerPO           NVARCHAR(20)   NULL
      , C_Company         NVARCHAR(45)   NULL
      , PWGT              DECIMAL(10,5)  NULL
      , PCube             DECIMAL(10,5)  NULL
      , PISTTLWGT         DECIMAL(10,5)  NULL
      , PISTTTLCUBE       DECIMAL(10,5)  NULL
      , LabelLine         NVARCHAR(5)    NULL
      , PackQtyIndicator  INT            NULL
      , PackUOM3          NVARCHAR(10)   NULL
      , LabelNo           NVARCHAR(20)   NULL
      , ShowFullSKU       NVARCHAR(30)   NULL
      , LBIShipNo         NVARCHAR(30)   NULL
      , showlbiship       NVARCHAR(30)   NULL
      , LSite             NVARCHAR(50)   NULL
      , Refno             NVARCHAR(20)   NULL
      , Refno2            NVARCHAR(30)   NULL
      , ExternPOKey       NVARCHAR(30)   NULL
   )

   INSERT INTO #TMP_PACKDET
   (    Orderkey
      , ExternOrderkey
      , ConsigneeKey
      , C_Contact1
      , C_Address1
      , C_Address2
      , C_Address3
      , C_Address4
      , C_Phone1
      , DeliveryDate
      , SKU
      , CartonNo
      , PickSlipNo
      , LoadKey
      , PackQty
      , BuyerPO
      , C_Company
      , PWGT
      , PCube
      , PISTTLWGT
      , PISTTTLCUBE
      , LabelLine
      , PackQtyIndicator
      , PackUOM3
      , LabelNo
      , ShowFullSKU
      , LBIShipNo
      , showlbiship
      , Lsite
      , Refno
      , Refno2
      , ExternPOKey
   )

   SELECT ORDERS.OrderKey,
         ORDERS.ExternOrderKey,
         ORDERS.ConsigneeKey,
         ORDERS.C_contact1,
         ORDERS.C_Address1,
         ORDERS.C_Address2,
         ORDERS.C_Address3,
         ORDERS.C_Address4,
         ORDERS.C_Phone1,
         ORDERS.DeliveryDate,
         PackDetail.SKU,
         PackDetail.CartonNo,
         PackHeader.PickSlipNo,
         PackHeader.LoadKey,
         SUM(Packdetail.Qty) AS PackQty ,
         ORDERS.BuyerPO ,
         ORDERS.C_Company,
         CONVERT(DECIMAL(10,5), ISNULL(PACKINFO.Weight,0)) AS PWGT,
         CONVERT(DECIMAL(10,5), ISNULL(PACKINFO.[Cube],0)) AS PCube,
         CONVERT(DECIMAL(10,5), ISNULL(PACKINFOSUM.TotalWeight,0)) AS PISTTLWGT,
         CONVERT(DECIMAL(10,5), ISNULL(PACKINFOSUM.TotalCube,0)) AS PISTTTLCUBE,
         '' AS LabelLine,
         SKU.PackQtyIndicator,
         PACK.PackUOM3,
         PackDetail.LabelNo,
         'Y' AS ShowFullSKU,
         CASE WHEN ISNULL(CLR1.Code,'') = '' THEN '' ELSE ('2' + RIGHT(ORDERS.orderkey,9)) END AS LBIShipNo,
         CASE WHEN ISNULL(CLR1.Code,'') = '' THEN 'N' ELSE 'Y' END AS showlbiship
         ,'' AS [SITE]                                                       
         ,CASE WHEN @c_zone <> '' THEN PACKDETAIL.RefNo ELSE '' END          
         ,CASE WHEN @c_zone <> '' THEN PACKDETAIL.RefNo2 ELSE '' END    
         ,ORDERS.ExternPOKey     
   FROM ORDERS (NOLOCK)
   JOIN PackHeader (NOLOCK) ON Packheader.Orderkey = Orders.Orderkey         
                              AND Packheader.Loadkey = Orders.Loadkey
                              AND Packheader.Consigneekey = Orders.Consigneekey 
   JOIN PackDetail (NOLOCK) ON ( PackDetail.PickSlipNo = PackHeader.PickSlipNo )
   JOIN SKU (NOLOCK) ON ( PackDetail.Sku = SKU.Sku AND PackDetail.StorerKey = SKU.StorerKey )
   JOIN PACK (NOLOCK) ON ( SKU.PackKey = PACK.PackKey )
   LEFT OUTER JOIN PACKINFO (NOLOCK) ON ( PackDetail.PickSlipNo = PACKINFO.PickSlipNo
                                      AND PackDetail.CartonNo = PACKINFO.CartonNo )
   LEFT OUTER JOIN ( SELECT PickSlipNo, SUM(Weight) AS TotalWeight, SUM(Cube) AS TotalCube
                     FROM PACKINFO (NOLOCK) GROUP BY PickSlipNo ) AS PACKINFOSUM
                ON ( PACKINFO.PickSlipNo = PACKINFOSUM.PickSlipNo )
   --LEFT OUTER JOIN Codelkup CLR (NOLOCK) ON (ORDERS.Storerkey = CLR.Storerkey AND CLR.Code = 'ShowFullSKU'
   --            AND CLR.Listname = 'REPORTCFG' AND CLR.Long = 'r_dw_packing_list_detail_o2' AND ISNULL(CLR.Short,'') <> 'N')
   LEFT OUTER JOIN Codelkup CLR1 (NOLOCK) ON (ORDERS.Storerkey = CLR1.Storerkey AND CLR1.Code = 'SHOWLBISHIP'
                                          AND CLR1.Listname = 'REPORTCFG' AND CLR1.Long = 'r_dw_packing_list_detail_o2' AND ISNULL(CLR1.Short,'') <> 'N')
   WHERE ( RTRIM(PackHeader.OrderKey) IS NOT NULL AND RTRIM(PackHeader.OrderKey) <> '') AND
          Packheader.Pickslipno = @c_pickslipno
   GROUP BY PackHeader.LoadKey,
            Orders.Consigneekey,
            Orders.Orderkey,
            Orders.ExternOrderkey,
            Orders.BuyerPO,
            Packheader.Pickslipno,
            Packdetail.CartonNo,
            Packdetail.Sku,
            Orders.C_Address1,
            Orders.C_Address2,
            Orders.C_Address3,
            Orders.C_Address4,
            Orders.C_contact1,
            Orders.C_Phone1,
            Orders.DeliveryDate,
            Orders.C_Company,
            CONVERT(DECIMAL(10,5), ISNULL(PACKINFO.Weight,0)),
            CONVERT(DECIMAL(10,5), ISNULL(PACKINFO.[Cube],0)),
            CONVERT(DECIMAL(10,5), ISNULL(PACKINFOSUM.TotalWeight,0)),
            CONVERT(DECIMAL(10,5), ISNULL(PACKINFOSUM.TotalCube,0)),
            SKU.PackQtyIndicator,
            PACK.PackUOM3,
            PackDetail.LabelNo,
            --CASE WHEN ISNULL(CLR.Code,'') = '' THEN 'N' ELSE 'Y' END,
            CASE WHEN ISNULL(CLR1.Code,'') = '' THEN '' ELSE ('2' + RIGHT(ORDERS.orderkey,9)) END,
            CASE WHEN ISNULL(CLR1.Code,'') = '' THEN 'N' ELSE 'Y' END
            ,CASE WHEN @c_zone <> '' THEN PACKDETAIL.RefNo ELSE '' END          
            ,CASE WHEN @c_zone <> '' THEN PACKDETAIL.RefNo2 ELSE '' END  
            ,ORDERS.ExternPOKey        
   UNION ALL
   SELECT '' AS OrderKey,
         '' AS ExternOrderKey,
         '' AS ConsigneeKey,
         MAX(ORDERS.C_contact1) AS C_contact1,
         MAX(ORDERS.C_Address1) AS C_Address1,
         MAX(ORDERS.C_Address2) AS C_Address2,
         MAX(ORDERS.C_Address3) AS C_Address3,
         MAX(ORDERS.C_Address4) AS C_Address4,
         MAX(ORDERS.C_Phone1) AS C_Phone1,
         MAX(ORDERS.DeliveryDate) AS DeliveryDate,
         PackDetail.SKU,
         PackDetail.CartonNo,
         PackHeader.PickSlipNo,
         PackHeader.LoadKey,
         Packdetail.Qty AS PackQty,
         '' AS BuyerPO,
         MAX(Orders.C_Company) AS C_Company,
         CONVERT(DECIMAL(10,5), ISNULL(PACKINFO.Weight,0)) AS PWGT,
         CONVERT(DECIMAL(10,5), ISNULL(PACKINFO.[Cube],0)) AS PCube,
         CONVERT(DECIMAL(10,5), ISNULL(PACKINFOSUM.TotalWeight,0)) AS PISTTLWGT,
         CONVERT(DECIMAL(10,5), ISNULL(PACKINFOSUM.TotalCube,0)) AS PISTTTLCUBE,
         Packdetail.LabelLine,
         SKU.PackQtyIndicator,
         PACK.PackUOM3,
         PackDetail.LabelNo,
         'Y' AS ShowFullSKU,
         CASE WHEN ISNULL(CLR1.Code,'') = '' THEN '' ELSE ('2' + RIGHT(ORDERS.orderkey,9)) END AS LBIShipNo,
         CASE WHEN ISNULL(CLR1.Code,'') = '' THEN 'N' ELSE 'Y' END AS showlbiship
         ,'' AS [SITE]                                    
         ,CASE WHEN @c_zone <> '' THEN PACKDETAIL.RefNo ELSE '' END          
         ,CASE WHEN @c_zone <> '' THEN PACKDETAIL.RefNo2 ELSE '' END    
         ,MAX(ORDERS.ExternPOKey)      
   FROM PackDetail (NOLOCK)
   JOIN PackHeader (NOLOCK) ON ( PackDetail.PickSlipNo = PackHeader.PickSlipNo )
   --JOIN LoadplanDetail (NOLOCK) ON ( Packheader.Loadkey = LoadplanDetail.LoadKey )    
   --JOIN ORDERS (NOLOCK) ON ( Orders.Orderkey = LoadplanDetail.OrderKey )
   JOIN  ORDERS (NOLOCK) ON Orders.loadkey = Packheader.loadkey                         
   JOIN SKU (NOLOCK) ON ( PackDetail.Sku = SKU.Sku AND PackDetail.StorerKey = SKU.StorerKey )
   JOIN PACK (NOLOCK) ON ( SKU.PackKey = PACK.PackKey )
   LEFT OUTER JOIN PACKINFO (NOLOCK) ON ( PackDetail.PickSlipNo = PACKINFO.PickSlipNo
                                      AND PackDetail.CartonNo = PACKINFO.CartonNo )
   LEFT OUTER JOIN ( SELECT PickSlipNo, SUM(Weight) AS TotalWeight, SUM(Cube) AS TotalCube
                     FROM PACKINFO (NOLOCK) GROUP BY PickSlipNo ) AS PACKINFOSUM
                ON ( PACKINFO.PickSlipNo = PACKINFOSUM.PickSlipNo )
   --LEFT OUTER JOIN Codelkup CLR (NOLOCK) ON (ORDERS.Storerkey = CLR.Storerkey AND CLR.Code = 'ShowFullSKU'
   --                                      AND CLR.Listname = 'REPORTCFG' AND CLR.Long = 'r_dw_packing_list_detail_o2' AND ISNULL(CLR.Short,'') <> 'N')
   LEFT OUTER JOIN Codelkup CLR1 (NOLOCK) ON (ORDERS.Storerkey = CLR1.Storerkey AND CLR1.Code = 'SHOWLBISHIP'
                                          AND CLR1.Listname = 'REPORTCFG' AND CLR1.Long = 'r_dw_packing_list_detail_o2' AND ISNULL(CLR1.Short,'') <> 'N')
   WHERE ( RTRIM(PackHeader.OrderKey) IS NULL OR RTRIM(PackHeader.OrderKey) = '') AND
         ( Packheader.Pickslipno = @c_pickslipno )
   GROUP BY Packheader.Loadkey,
            Packheader.Pickslipno,
            Packdetail.CartonNo,
            Packdetail.Sku,
            Packdetail.Qty,
            CONVERT(DECIMAL(10,5), ISNULL(PACKINFO.Weight,0)),
            CONVERT(DECIMAL(10,5), ISNULL(PACKINFO.[Cube],0)),
            CONVERT(DECIMAL(10,5), ISNULL(PACKINFOSUM.TotalWeight,0)),
            CONVERT(DECIMAL(10,5), ISNULL(PACKINFOSUM.TotalCube,0)),
            Packdetail.LabelLine,
            SKU.PackQtyIndicator,
            PACK.PackUOM3,
            PackDetail.LabelNo,
            --CASE WHEN ISNULL(CLR.Code,'') = '' THEN 'N' ELSE 'Y' END,
            CASE WHEN ISNULL(CLR1.Code,'') = '' THEN '' ELSE ('2' + RIGHT(ORDERS.orderkey,9)) END,
            CASE WHEN ISNULL(CLR1.Code,'') = '' THEN 'N' ELSE 'Y' END
           ,CASE WHEN @c_zone <> '' THEN PACKDETAIL.RefNo ELSE '' END           
           ,CASE WHEN @c_zone <> '' THEN PACKDETAIL.RefNo2 ELSE '' END         
   ORDER BY PACKDETAIL.CartonNo

   IF @c_Zone = '' 
   BEGIN
      SELECT
          Orderkey
         ,ExternOrderkey
         ,ConsigneeKey
         ,C_Contact1
         ,C_Address1
         ,C_Address2
         ,C_Address3
         ,C_Address4
         ,C_Phone1
         ,DeliveryDate
         ,SKU
         ,CartonNo
         ,PickSlipNo
         ,LoadKey
         ,PackQty
         ,BuyerPO
         ,C_Company
         ,PWGT
         ,PCube
         ,PISTTLWGT
         ,PISTTTLCUBE
         ,LabelLine
         ,PackQtyIndicator
         ,PackUOM3
         ,LabelNo
         ,ShowFullSKU
         ,LBIShipNo
         ,showlbiship
         ,@c_FUserdefine12
         ,ExternPOKey
      FROM #TMP_PACKDET AS tp
      ORDER BY CartonNo
   END
   ELSE
   BEGIN
       SET @n_cntRefno = 0
      
       SELECT @n_cntRefno = COUNT(DISTINCT c.code)
       FROM PackDetail (NOLOCK)
       JOIN PackHeader (NOLOCK) ON ( PackDetail.PickSlipNo = PackHeader.PickSlipNo )
       --JOIN LoadplanDetail (NOLOCK) ON ( Packheader.Loadkey = LoadplanDetail.LoadKey )
       --JOIN ORDERS (NOLOCK) ON ( Orders.Orderkey = LoadplanDetail.OrderKey )
	   JOIN  ORDERS (NOLOCK) ON Orders.loadkey = Packheader.loadkey
       JOIN SKU (NOLOCK) ON ( PackDetail.Sku = SKU.Sku AND PackDetail.StorerKey = SKU.StorerKey )
       LEFT JOIN PICKDETAIL PD (NOLOCK) ON PD.orderkey = ORDERS.OrderKey
       LEFT JOIN LOC L WITH (NOLOCK) ON L.loc=pd.Loc
       LEFT JOIN CODELKUP C WITH (NOLOCK) ON C.listname = 'ALLSorting' AND
       C.Storerkey=ORDERS.StorerKey AND C.code2=L.PickZone
       WHERE PackDetail.Pickslipno = @c_PickSlipNo
       AND Packdetail.RefNo<>@c_Zone

       IF @n_cntRefno = 0
       BEGIN
          SELECT @n_cntRefno = COUNT(DISTINCT c.code)
          FROM ORDERS (NOLOCK)
         -- JOIN PackDetail (NOLOCK) ON ( ORDERS.StorerKey = PackDetail.StorerKey )     
          JOIN PackHeader (NOLOCK) ON ( Packheader.Orderkey = Orders.Orderkey           
                                    AND Packheader.Loadkey = Orders.Loadkey
                                    AND Packheader.Consigneekey = Orders.Consigneekey )
           JOIN PackDetail (NOLOCK) ON ( PackDetail.PickSlipNo = PackHeader.PickSlipNo )
          LEFT JOIN PICKDETAIL PD (NOLOCK) ON PD.orderkey = ORDERS.OrderKey
          LEFT JOIN LOC L WITH (NOLOCK) ON L.loc=pd.Loc
          LEFT JOIN CODELKUP C WITH (NOLOCK) ON C.listname = 'ALLSorting' AND
          C.Storerkey=ORDERS.StorerKey AND C.code2=L.PickZone
          WHERE PackDetail.Pickslipno = @c_PickSlipNo
          AND Packdetail.RefNo<>@c_Zone
       END

      SET @c_site = ''

      SELECT @c_site = CASE WHEN ISNULL(c.code,'') <> '' THEN c.code ELSE l.pickzone END
      FROM PackDetail (NOLOCK)
      JOIN PackHeader (NOLOCK) ON ( PackDetail.PickSlipNo = PackHeader.PickSlipNo )
      --JOIN LoadplanDetail (NOLOCK) ON ( Packheader.Loadkey = LoadplanDetail.LoadKey )    
      --JOIN ORDERS (NOLOCK) ON ( Orders.Orderkey = LoadplanDetail.OrderKey )              
	  JOIN ORDERS (NOLOCK) ON ( Orders.loadkey = PackHeader.loadkey )                
      JOIN SKU (NOLOCK) ON ( PackDetail.Sku = SKU.Sku AND PackDetail.StorerKey = SKU.StorerKey )
      LEFT JOIN PICKDETAIL PD (NOLOCK) ON PD.orderkey = ORDERS.OrderKey
      LEFT JOIN LOC L WITH (NOLOCK) ON L.loc=pd.Loc
      LEFT JOIN CODELKUP C WITH (NOLOCK) ON C.listname = 'ALLSorting' AND C.Storerkey=ORDERS.StorerKey AND C.code2=L.PickZone
      WHERE PackDetail.Pickslipno = @c_PickSlipNo
      AND ISNULL(RTRIM(Packdetail.RefNo),'') <> @c_Zone

      IF @c_site = ''
      BEGIN
         SELECT @c_site = CASE WHEN ISNULL(c.code,'') <> '' THEN c.code ELSE l.pickzone END
         FROM ORDERS (NOLOCK)
         --JOIN PackDetail (NOLOCK) ON ( ORDERS.StorerKey = PackDetail.StorerKey )                 
         JOIN PackHeader (NOLOCK) ON ( Packheader.Orderkey = Orders.Orderkey                       
                                    AND Packheader.Loadkey = Orders.Loadkey
                                    AND Packheader.Consigneekey = Orders.Consigneekey )
         JOIN PackDetail (NOLOCK) ON ( PackDetail.PickSlipNo = PackHeader.PickSlipNo )         
         LEFT JOIN PICKDETAIL PD (NOLOCK) ON PD.orderkey = ORDERS.OrderKey
         LEFT JOIN LOC L WITH (NOLOCK) ON L.loc=pd.Loc
         LEFT JOIN CODELKUP C WITH (NOLOCK) ON C.listname = 'ALLSorting' AND
         C.Storerkey=ORDERS.StorerKey AND C.code2=L.PickZone
         WHERE PackDetail.Pickslipno = @c_PickSlipNo
         AND ISNULL(RTRIM(Packdetail.RefNo),'') <> @c_Zone
      END

      SET @n_NewCartonNo = 1

      DECLARE CUR_ResetCartonNo CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT DISTINCT CartonNo
         FROM #TMP_PACKDET WITH (NOLOCK)
         WHERE Pickslipno = @c_PickSlipNo
         AND ISNULL(RTRIM(RefNo),'') <> @c_Zone
         ORDER BY CartonNo

      OPEN CUR_ResetCartonNo
      FETCH NEXT FROM CUR_ResetCartonNo INTO @n_OriginalCartonNo
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         BEGIN TRAN
         UPDATE #TMP_PACKDET WITH (ROWLOCK)
         SET CartonNo = @n_NewCartonNo
         WHERE Pickslipno = @c_PickSlipNo
         AND ISNULL(RTRIM(RefNo),'') <> @c_Zone
         AND CartonNo = @n_OriginalCartonNo
         IF @@ERROR <> 0
         BEGIN
            ROLLBACK TRAN
            BREAK
         END
         ELSE
         BEGIN
            COMMIT TRAN
         END
         SET @n_NewCartonNo = @n_NewCartonNo + 1
         FETCH NEXT FROM CUR_ResetCartonNo INTO @n_OriginalCartonNo
      END
      CLOSE CUR_ResetCartonNo
      DEALLOCATE CUR_ResetCartonNo

      SELECT
           Orderkey
         , ExternOrderkey
         , ConsigneeKey
         , C_Contact1
         , C_Address1
         , C_Address2
         , C_Address3
         , C_Address4
         , C_Phone1
         , DeliveryDate
         , SKU
         , CASE WHEN ISNULL(RTRIM(RefNo2),'') <> '' THEN ISNULL(RTRIM(RefNo2),'')
                ELSE CartonNo END AS CartonNo
         , PickSlipNo
         ,  CASE WHEN @n_cntRefno >1 THEN @c_RefNo + '-' + LoadKey ELSE loadkey END AS loadkey
         , PackQty
         , BuyerPO
         , C_Company
         , PWGT
         , PCube
         , PISTTLWGT
         , PISTTTLCUBE
         , LabelLine
         , PackQtyIndicator
         , PackUOM3
         , LabelNo
         , ShowFullSKU
         , LBIShipNo
         , showlbiship
         , @c_FUserdefine12 AS [Site]--CASE WHEN @n_cntRefno>1 THEN @c_RefNo ELSE '' END AS LSite
         ,ExternPOKey
       FROM #TMP_PACKDET AS tp
       WHERE Pickslipno = @c_PickSlipNo
       AND ISNULL(RTRIM(RefNo),'') <> @c_Zone
       AND ISNULL(RTRIM(RefNo),'') = @c_RefNo
       ORDER BY Pickslipno, CartonNo
   END
END

SET QUOTED_IDENTIFIER OFF

GO