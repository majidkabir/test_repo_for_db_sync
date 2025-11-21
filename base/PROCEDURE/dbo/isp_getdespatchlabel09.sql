SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/      
/* Stored Procedure: isp_GetDespatchLabel09                             */      
/* Creation Date: 09-Feb-2011                                           */      
/* Copyright: IDS                                                       */      
/* Written by: NJOW                                                     */      
/*                                                                      */      
/* Purpose: Despatch Label For UK C&C  (Refer fr isp_GetDespatchLabel08)*/      
/*          SOS#202454                                                  */      
/*                                                                      */      
/* Called By:                                                           */      
/*                                                                      */      
/* PVCS Version: 1.0                                                    */      
/*                                                                      */      
/* Version: 5.4                                                         */      
/*                                                                      */      
/* Data Modifications:                                                  */      
/*                                                                      */      
/* Updates:                                                             */      
/* Date         Author  Ver Purposes                                    */      
/* 28-Feb-2011  James   1.1 Add ORDERS.C_Company (james01)              */
/* 19-May-2011  NJOW01  1.2 215965 - Add Orders.adddate                 */
/* 13-Sep-2014  James   1.3 SOS320518 - Add OD.Userdefine05 (james02)   */
/* 23-Sep-2014  James   1.4 SOS321615 - Add O.C_City (james03)          */
/* 24-Sep-2014  James   1.5 SOS321760 - Add O.C_Zip (james04)           */
/* 11-Feb-2015  CSCHONG 1.6 SOS332914 - Add Storer.company (CS01)       */
/************************************************************************/      
CREATE PROC [dbo].[isp_GetDespatchLabel09]   
(  
    @cStorerKey          NVARCHAR(15)  
   ,@cOrderKey           NVARCHAR(10)  
   ,@cRefNo              NVARCHAR(20) = ''      
   ,@cExternOrderKey     NVARCHAR(30) = ''      
)      
AS      
BEGIN  
    SET NOCOUNT ON      
    SET QUOTED_IDENTIFIER OFF      
    SET ANSI_NULLS OFF      
    SET CONCAT_NULL_YIELDS_NULL OFF  
      
    DECLARE @nTot_Pick   INT,
            @nTot_Pack   INT, 
            @cUserDefine05 NVARCHAR ( 18) -- (james02)
            
   IF RTRIM(ISNULL(@cOrderKey,'')) = '' AND RTRIM(ISNULL(@cRefNo,'')) <> ''  
   BEGIN      
      SELECT @cOrderKey = PACKHEADER.OrderKey,   
             @cStorerKey = ORDERS.StorerKey   
      FROM PACKDETAIL WITH (NOLOCK)   
      JOIN PACKHEADER WITH (NOLOCK) ON (PACKDETAIL.PickSlipNo = PACKHEADER.PickSlipNo)  
      JOIN ORDERS WITH (NOLOCK) ON (PACKHEADER.OrderKey = ORDERS.OrderKey)  
      WHERE PACKDETAIL.RefNo = @cRefNo   
   END  
   
   IF RTRIM(ISNULL(@cOrderKey,'')) = '' AND RTRIM(ISNULL(@cExternOrderKey,'')) <> ''  
   BEGIN      
      SELECT @cOrderKey = OrderKey    
      FROM Orders WITH (NOLOCK)   
      WHERE StorerKey = @cStorerKey  
      AND ExternOrderKey = @cExternOrderKey  
      AND Status <> 'CANC'   
   END  
   
   SELECT @nTot_Pick = ISNULL(SUM(QTY), 0) 
   FROM PICKDETAIL PD WITH (NOLOCK) 
   WHERE StorerKey = @cStorerKey
      AND OrderKey = @cOrderKey
      AND Status >= '5'

   SELECT @nTot_Pack = ISNULL(SUM(QTY), 0) 
   FROM PACKDETAIL PD WITH (NOLOCK)
   JOIN PACKHEADER PH WITH (NOLOCK) ON (PD.PickSlipNo = PH.PickSlipNo)
   WHERE PH.StorerKey = @cStorerKey
      AND PH.OrderKey = @cOrderKey

   IF @nTot_Pick <> @nTot_Pack
   BEGIN
      SELECT TOP 1 SUBSTRING(ISNULL(ORDERS.Consigneekey,''),4,4) AS StoreNo,
             RIGHT('00000000000'+ISNULL(LTRIM(RTRIM(Orders.Externorderkey)),''),11) AS CCExternorderkey,
             ORDERS.C_Contact1 AS C_Contact1,
             ORDERS.M_Contact1 AS M_Contact1,
             ORDERS.ExternOrderkey AS ExternOrderkey,
             ORDERS.Incoterm AS Incoterm,
             ORDERS.Orderkey AS Orderkey, 
             ORDERS.C_Company AS C_Company,    -- (james01)
             ORDERS.Adddate AS Adddate, 
             '' AS Userdefine05,               -- (james02)
             ORDERS.C_City AS C_City,          -- (james03)
             ORDERS.C_Zip AS C_Zip,            -- (james04)
             CASE WHEN ISNULL(STORER.Company,'') <> '' THEN STORER.company ELSE 'NO STORE' END AS S_Company      --(CS01) 
      FROM ORDERS WITH (NOLOCK)
      JOIN PACKHEADER WITH (NOLOCK) ON (ORDERS.OrderKey = PACKHEADER.OrderKey) 
      JOIN PACKDETAIL WITH (NOLOCK) ON (PACKHEADER.PickSlipNo = PACKDETAIL.PickSlipNo)  
      LEFT JOIN STORER WITH (NOLOCK) ON STORER.Zip = ORDERS.C_Zip AND STORER.type='2'                      --(CS01)
      WHERE 1=2
      
      GOTO Quit
   END

    -- (james02)
    SET @cUserDefine05 = ''
    SELECT TOP 1 @cUserDefine05 = UserDefine05 
    FROM OrderDetail WITH (NOLOCK) 
    WHERE OrderKey = @cOrderkey
    AND   Storerkey = @cStorerKey
    AND   SKU IN ( SELECT DISTINCT SKU FROM PackDetail PD WITH (NOLOCK) 
                   JOIN PackHeader PH WITH (NOLOCK) ON PD.PickSlipNo = PH.PickSlipNo
                   WHERE PH.OrderKey =  @cOrderkey
                   AND   PH.StorerKey = @cStorerKey)

    SELECT TOP 1 SUBSTRING(ISNULL(ORDERS.Consigneekey,''),4,4) AS StoreNo,
           RIGHT('00000000000'+ISNULL(LTRIM(RTRIM(Orders.Externorderkey)),''),11) AS CCExternorderkey,
           ORDERS.C_Contact1 AS C_Contact1,
           ORDERS.M_Contact1 AS M_Contact1,
           ORDERS.ExternOrderkey AS ExternOrderkey,
           ORDERS.Incoterm AS Incoterm,
           ORDERS.Orderkey AS Orderkey, 
           ORDERS.C_Company AS C_Company,   -- (james01)
           ORDERS.Adddate AS Adddate, 
           @cUserDefine05 AS UserDefine05, 
           ORDERS.C_City AS C_City, 
           ORDERS.C_Zip AS C_Zip,            -- (james04)
           CASE WHEN ISNULL(STORER.Company,'') <> '' THEN STORER.company ELSE 'NO STORE' END AS S_Company      --(CS01) 
    FROM ORDERS WITH (NOLOCK)
    JOIN PACKHEADER WITH (NOLOCK) ON (ORDERS.OrderKey = PACKHEADER.OrderKey) 
    JOIN PACKDETAIL WITH (NOLOCK) ON (PACKHEADER.PickSlipNo = PACKDETAIL.PickSlipNo)  
    LEFT JOIN STORER WITH (NOLOCK) ON STORER.Zip = ORDERS.C_Zip AND STORER.type='2'                      --(CS01)
    WHERE Orders.Storerkey = @cStorerKey
    AND ORDERS.Orderkey = @cOrderkey
    AND ORDERS.IncoTerm = 'CC'
       
Quit:

END -- procedure     

GO