SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Stored Procedure: isp_Pallet_Manifest_03_rdt                         */  
/* Creation Date: 04-Oct-2022                                           */  
/* Copyright: LFL                                                       */  
/* Written by: WLChooi                                                  */  
/*                                                                      */  
/* Purpose: WMS-20926 - TH ADIDAS Pallet Manifest                       */  
/*                                                                      */  
/* Called By: r_dw_pallet_manifest_03_rdt                               */   
/*                                                                      */  
/* Parameters:                                                          */  
/*                                                                      */  
/* GitLab Version: 1.0                                                  */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author    Ver.  Purposes                                */  
/* 04-Oct-2022  WLChooi   1.0   DevOps Combine Script                   */
/************************************************************************/  
CREATE   PROCEDURE [dbo].[isp_Pallet_Manifest_03_rdt]  
      @c_Storerkey      NVARCHAR(15)
    , @c_Palletkey      NVARCHAR(50)
AS  
BEGIN   
   SET NOCOUNT ON  
   SET ANSI_DEFAULTS OFF    
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @n_continue        INT
         , @n_Cnt             INT = 150
         , @n_MaxLinePerPage  INT = 64
         , @n_CurrentCnt      INT
         , @n_starttcnt       INT

   SELECT @n_Continue = 1, @n_starttcnt = @@TRANCOUNT
   
   DECLARE @T_PALLET TABLE (  BuyerPO     NVARCHAR(20) NULL
                            , Shipperkey  NVARCHAR(15) NULL
                            , TrackingNo  NVARCHAR(50) NULL
                            , CustPO      NVARCHAR(20) NULL
                            , Palletkey   NVARCHAR(50) NULL
                           )
   INSERT INTO @T_PALLET
   SELECT ISNULL(TRIM(OH.BuyerPO   ),'') AS BuyerPO
        , ISNULL(TRIM(OH.Shipperkey),'') AS Shipperkey
        , ISNULL(TRIM(OH.TrackingNo),'') AS TrackingNo
        , CASE WHEN ISNULL(CL.Code,'') = '' THEN OH.UserDefine05 ELSE OH.xdockpokey END AS CustPO
        , PL.PalletKey
   FROM PALLET PL WITH (NOLOCK) 
   JOIN PALLETDETAIL PLTD WITH (NOLOCK) ON PL.PalletKey = PLTD.PalletKey
   JOIN ORDERS OH WITH (NOLOCK) ON PL.StorerKey = OH.StorerKey
                               AND PLTD.TrackingNo = OH.TrackingNo
   LEFT JOIN CODELKUP CL WITH (NOLOCK) ON CL.Storerkey = OH.StorerKey AND CL.Code = OH.BuyerPO 
                                      AND CL.Listname = 'PLATFLKUP'
   WHERE PL.Storerkey = @c_Storerkey
   AND PL.PalletKey = @c_Palletkey
   AND OH.TrackingNo <> ''

   SELECT TP.BuyerPO   
        , TP.Shipperkey
        , TP.TrackingNo
        , TP.CustPO    
        , TP.Palletkey 
        , (Row_Number() OVER (PARTITION BY TP.PalletKey 
           ORDER BY TP.PalletKey, TP.CustPO, TP.TrackingNo) - 1 ) / @n_MaxLinePerPage + 1 AS PageNo
   FROM @T_PALLET TP
   ORDER BY TP.PalletKey, TP.CustPO, TP.TrackingNo

QUIT_SP:     
END

GO