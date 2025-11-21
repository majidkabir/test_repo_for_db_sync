SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*************************************************************************/  
/* Stored Procedure: isp_ShippingDashBoard                               */  
/* Creation Date: 17-OCT-2012                                            */  
/* Copyright: IDS                                                        */  
/* Written by: YTWan                                                     */  
/*                                                                       */  
/* Purpose: SOS#257515: WMS Shipping DashBoard                           */  
/*                                                                       */  
/* Called By: Call from Shipping DashBoard                               */
/*                      datawindow - d_dw_shipping_dashboard             */  
/*                                                                       */  
/* PVCS Version: 1.0                                                     */  
/*                                                                       */  
/* Version: 5.4                                                          */  
/*                                                                       */  
/* Data Modifications:                                                   */  
/*                                                                       */  
/* Updates:                                                              */  
/* Date         Author   Ver  Purposes                                   */  
/*************************************************************************/  

CREATE PROC [dbo].[isp_ShippingDashBoard]
      @c_Storerkey      NVARCHAR(15)
   ,  @c_Facility       NVARCHAR(5)
AS  
BEGIN
   SET NOCOUNT ON   
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  

   CREATE TABLE #TMPMBOL
      (     Storerkey   NVARCHAR(15)
         ,  facility    NVARCHAR(5)  
         ,  CBOLKey     INT         NULL
         ,  MBOLKey     NVARCHAR(10)
         ,  ETD         DATETIME    NULL
         ,  Door        NVARCHAR(30)
         ,  CID         NVARCHAR(30)
         ,  Orderkey    NVARCHAR(10) 
         ,  PickSlipNo  NVARCHAR(10) NULL
         ,  CartonLBL   NVARCHAR(20) NULL
         ,  DropID      NVARCHAR(20) NULL
         ,  LocCategory NVARCHAR(10) NULL
      )


   INSERT INTO #TMPMBOL (Storerkey, facility, CBOLKey, MBOLKey, ETD, Door, CID, Orderkey, PickSlipNo, CartonLBL, DropID, LocCategory)
   SELECT OD.Storerkey
         ,MH.Facility
         ,CBOLKey = CASE WHEN MH.CBOLKey = 0 OR MH.CBOLKey IS NULL THEN NULL ELSE MH.CBOLKey END
         ,MH.MBOLKey
         ,ETD             = CASE WHEN CB.PickupDate IS NULL THEN MH.DepartureDate ELSE CB.PickupDate END
         ,PlaceOfLoading  = ISNULL(RTRIM(MH.PlaceOfLoading),'')
         ,BookingReference= ISNULL(RTRIM(MH.BookingReference),'')
         ,OD.Orderkey
         ,PickSlipNo = ISNULL(PH.PickSlipNo,'')
         ,CartonLBL  = CASE WHEN ISNULL(RTRIM(PD.RefNo2),'') = '' THEN PD.LabelNo ELSE PD.RefNo2 END
         ,DropID     = DH.DropID
         ,LocCategory= RTRIM(L.LocationCategory)
   FROM MBOL  MH WITH (NOLOCK)
   JOIN MBOLDETAIL   MD WITH (NOLOCK) ON (MH.MBOLKey = MD.MBOLKey)
   JOIN ORDERDETAIL  OD WITH (NOLOCK) ON (MD.Orderkey= OD.Orderkey)
   LEFT JOIN CBOL    CB WITH (NOLOCK) ON (MH.CBOLKey = CB.CBOLKey)
   LEFT JOIN PACKHEADER   PH WITH (NOLOCK) ON (OD.ConsoOrderkey = PH.ConsoOrderkey) 
   LEFT JOIN PACKDETAIL   PD WITH (NOLOCK) ON (PH.PickSlipNo = PD.PickSlipNo)
   LEFT JOIN DROPIDDETAIL DD WITH (NOLOCK) ON (PD.LabelNo = DD.ChildID)
   LEFT JOIN DROPID       DH WITH (NOLOCK) ON (DD.DropID = DH.DropID)
   LEFT JOIN LOC          L  WITH (NOLOCK) ON (DH.Droploc = L.Loc) 
   WHERE (MH.Facility = CASE WHEN @c_Facility = 'ALL' THEN MH.Facility ELSE @c_Facility END)
   AND   (OD.Storerkey= CASE WHEN @c_Storerkey= 'ALL' THEN OD.Storerkey ELSE @c_Storerkey END)
   AND   (MH.BookingReference IS NOT NULL AND RTRIM(MH.BookingReference) <> '')
   AND   (PH.ConsoOrderkey IS NOT NULL AND RTRIM(PH.ConsoOrderkey) <> '')
   UNION
   SELECT OD.Storerkey
         ,MH.Facility
         ,CBOLKey = CASE WHEN MH.CBOLKey = 0 OR MH.CBOLKey IS NULL THEN NULL ELSE MH.CBOLKey END
         ,MH.MBOLKey
         ,ETD             = CASE WHEN CB.PickupDate IS NULL THEN MH.DepartureDate ELSE CB.PickupDate END
         ,PlaceOfLoading  = ISNULL(RTRIM(MH.PlaceOfLoading),'')
         ,BookingReference= ISNULL(RTRIM(MH.BookingReference),'')
         ,OD.Orderkey
         ,PickSlipNo = ISNULL(PH.PickSlipNo,'')
         ,CartonLBL  = CASE WHEN ISNULL(RTRIM(PD.RefNo2),'') = '' THEN PD.LabelNo ELSE PD.RefNo2 END
         ,DropID     = ISNULL(DH.DropID, '')
         ,LocCategory= RTRIM(L.LocationCategory)
   FROM MBOL  MH WITH (NOLOCK)
   JOIN MBOLDETAIL   MD WITH (NOLOCK) ON (MH.MBOLKey = MD.MBOLKey)
   JOIN ORDERDETAIL  OD WITH (NOLOCK) ON (MD.Orderkey= OD.Orderkey)
   LEFT JOIN CBOL    CB WITH (NOLOCK) ON (MH.CBOLKey = CB.CBOLKey)
   LEFT JOIN PACKHEADER   PH WITH (NOLOCK) ON (OD.Orderkey= PH.Orderkey) 
   LEFT JOIN PACKDETAIL   PD WITH (NOLOCK) ON (PH.PickSlipNo = PD.PickSlipNo)
   LEFT JOIN DROPIDDETAIL DD WITH (NOLOCK) ON (PD.LabelNo = DD.ChildID)
   LEFT JOIN DROPID       DH WITH (NOLOCK) ON (DD.DropID = DH.DropID)
   LEFT JOIN LOC          L  WITH (NOLOCK) ON (DH.Droploc = L.Loc) 
   WHERE (MH.Facility = CASE WHEN @c_Facility = 'ALL' THEN MH.Facility ELSE @c_Facility END)
   AND   (OD.Storerkey= CASE WHEN @c_Storerkey= 'ALL' THEN OD.Storerkey ELSE @c_Storerkey END)
   AND   (MH.BookingReference IS NOT NULL AND RTRIM(MH.BookingReference) <> '')
   AND   (PH.Orderkey IS NOT NULL AND RTRIM(PH.Orderkey) <> '')
   UNION
   SELECT OD.Storerkey
         ,MH.Facility
         ,CBOLKey = CASE WHEN MH.CBOLKey = 0 OR MH.CBOLKey IS NULL THEN NULL ELSE MH.CBOLKey END
         ,MH.MBOLKey
         ,ETD             = CASE WHEN CB.PickupDate IS NULL THEN MH.DepartureDate ELSE CB.PickupDate END
         ,PlaceOfLoading  = ISNULL(RTRIM(MH.PlaceOfLoading),'')
         ,BookingReference= ISNULL(RTRIM(MH.BookingReference),'')
         ,OD.Orderkey
         ,PickSlipNo = ISNULL(PH.PickSlipNo,'')
         ,CartonLBL  = CASE WHEN ISNULL(RTRIM(PD.RefNo2),'') = '' THEN PD.LabelNo ELSE PD.RefNo2 END
         ,DropID     = DH.DropID
         ,LocCategory= RTRIM(L.LocationCategory)
   FROM MBOL  MH WITH (NOLOCK)
   JOIN MBOLDETAIL   MD WITH (NOLOCK) ON (MH.MBOLKey = MD.MBOLKey)
   JOIN ORDERDETAIL  OD WITH (NOLOCK) ON (MD.Orderkey= OD.Orderkey)
   LEFT JOIN CBOL    CB WITH (NOLOCK) ON (MH.CBOLKey = CB.CBOLKey)
   LEFT JOIN PACKHEADER   PH WITH (NOLOCK) ON (OD.Loadkey = PH.Loadkey) 
   LEFT JOIN PACKDETAIL   PD WITH (NOLOCK) ON (PH.PickSlipNo = PD.PickSlipNo)
   LEFT JOIN DROPIDDETAIL DD WITH (NOLOCK) ON (PD.LabelNo = DD.ChildID)
   LEFT JOIN DROPID       DH WITH (NOLOCK) ON (DD.DropID = DH.DropID)
   LEFT JOIN LOC          L  WITH (NOLOCK) ON (DH.Droploc = L.Loc) 
   WHERE (MH.Facility = CASE WHEN @c_Facility = 'ALL' THEN MH.Facility ELSE @c_Facility END)
   AND   (OD.Storerkey= CASE WHEN @c_Storerkey= 'ALL' THEN OD.Storerkey ELSE @c_Storerkey END)
   AND   (MH.BookingReference IS NOT NULL AND RTRIM(MH.BookingReference) <> '')
   AND   (PH.Loadkey IS NOT NULL AND RTRIM(PH.Loadkey) <> '')
   AND   (PH.Orderkey IS NULL OR RTRIM(PH.Orderkey) = '')
   AND   (PH.ConsoOrderkey IS NULL OR RTRIM(PH.ConsoOrderkey) = '')

   SELECT TMP.Storerkey
         ,TMP.Facility
         ,TMP.ETD
         ,TMP.Door
         ,TMP.CID
         ,NoOfMBOL = COUNT(DISTINCT TMP.MBOLKey)
         ,NoOfOrder= COUNT(DISTINCT TMP.OrderKey)
         ,NoOfCBOL = COUNT(DISTINCT TMP.CBOLKey)
         ,NoOfCTN  = COUNT(DISTINCT TMP.CartonLbl)
         ,NoOfCTNPDToStage= COUNT(DISTINCT CASE WHEN ISNULL(RTRIM(TMP.LocCategory),'') NOT IN ('STAGE','DOOR')  
                                                THEN TMP.CartonLBL ELSE NULL END)
         ,NoOfCTNOnStage  = COUNT(DISTINCT CASE WHEN TMP.LocCategory = 'STAGE' THEN TMP.CartonLBL ELSE NULL END)
         ,NoOfCTNAtDoor   = COUNT(DISTINCT CASE WHEN TMP.LocCategory = 'DOOR' THEN TMP.CartonLBL ELSE NULL END)
         ,CompletePctg = CASE WHEN  COUNT(DISTINCT TMP.CartonLBL) = 0 THEN 0.00
                              ELSE  CONVERT( DECIMAL(5,2),CONVERT(REAL, COUNT(DISTINCT 
                                                          CASE WHEN TMP.LocCategory = 'DOOR' THEN TMP.CartonLBL ELSE NULL END))
                                                        / COUNT(DISTINCT TMP.CartonLBL) * 100 )
                              END
   FROM #TMPMBOL TMP
   GROUP BY TMP.Storerkey
         ,  TMP.Facility
         ,  TMP.ETD
         ,  TMP.Door
         ,  TMP.CID
   ORDER BY TMP.Door
         ,  TMP.CID
END

GO