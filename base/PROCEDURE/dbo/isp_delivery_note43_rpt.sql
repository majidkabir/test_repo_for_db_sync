SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Stored Proc: isp_delivery_note43_rpt                                 */  
/* Creation Date: 15-Oct-2019                                           */  
/* Copyright: LF Logistics                                              */  
/* Written by: WLChooi                                                  */  
/*                                                                      */  
/* Purpose: WMS-10893 - CN - PVHQHW Delivery Note Report                */   
/*        :                                                             */  
/* Called By: r_dw_delivery_note43_rpt                                  */
/*          : Copy from r_hk_delivery_note_04                           */  
/*          :                                                           */  
/* PVCS Version: 1.2                                                    */  
/*                                                                      */  
/* Version: 7.0                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author    Ver   Purposes                                */  
/* 08-May-2020  WLChooi   1.1   WMS-13263 - Revised field logic (WL01)  */
/* 15-Apr-2021  WLChooi   1.2   WMS-16822 - Modify Logic (WL02)         */
/************************************************************************/ 

CREATE PROC [dbo].[isp_delivery_note43_rpt]  
            @c_storerkey   NVARCHAR(15)  
         ,  @c_Mbolkey     NVARCHAR(4000)  
AS  
BEGIN   
   SET NOCOUNT ON        
   SET ANSI_NULLS OFF        
   SET QUOTED_IDENTIFIER OFF        
   SET CONCAT_NULL_YIELDS_NULL OFF    
   
   DECLARE @n_continue INT = 1, @n_err INT = 0, @c_errmsg NVARCHAR(255) = '', @b_Success INT = 1
   DECLARE @n_StartTCnt INT = @@TRANCOUNT
   
   IF @c_Mbolkey = NULL SET @c_Mbolkey = ''
             
   DECLARE @c_DataWindow NVARCHAR(100)
   SET @c_DataWindow = 'r_dw_delivery_note43_rpt'

   SELECT Loadkey           = X.Loadkey   --WL02
        , BookingReference  = MAX( IIF(X.BookingReference<>'', X.BookingReference, X.MBOLKey) )   --WL02
        , Storerkey         = MAX( X.Storerkey )
        , Company           = MAX( X.Company )
        , C_Company         = MAX( CASE WHEN X.SeqNo=1 THEN IIF(X.CarrierAgent<>'', X.CarrierAgent, X.ConsigneeKey +' - '+ X.C_Company) END )
        , C_Address         = MAX( CASE WHEN X.SeqNo=1 THEN IIF(X.CarrierAgent<>'', X.LFLContactAddress, X.C_Address) END )
        , C_Country         = MAX( CASE WHEN X.SeqNo=1 THEN X.C_Country    END )
        , SoldTo            = MAX( CASE WHEN X.SeqNo=1 THEN X.SoldTo       END )
        , DeliveryDate      = MAX( CASE WHEN X.SeqNo=1 THEN X.DeliveryDate END )
        , Line_No           = FLOOR((X.SeqNo-1)/2) + 1
        , ExternOrderKey1   = MAX( CASE WHEN (X.SeqNo-1) % 2 = 0 THEN X.ExternOrderKey END )
        , NoOfCtn1          = MAX( CASE WHEN (X.SeqNo-1) % 2 = 0 THEN X.NoOfCtn        END )
        , ExternOrderKey2   = MAX( CASE WHEN (X.SeqNo-1) % 2 = 1 THEN X.ExternOrderKey END )
        , NoOfCtn2          = MAX( CASE WHEN (X.SeqNo-1) % 2 = 1 THEN X.NoOfCtn        END )
        , LFLContactName    = MAX( X.LFLContactName )
        , LFLContactAddress = MAX( X.LFLContactAddress )
        , LFLContactPhone   = MAX( X.LFLContactPhone )
        , MBOLKey           = MAX( X.MBOLKey )  --WL02
   FROM (
      SELECT Loadkey          = ORD.Loadkey   --WL02
           , BookingReference = ORD.BookingReference
           , PickSlipNo       = ORD.PickSlipNo
           , Storerkey        = ORD.Storerkey
           , Company          = ORD.Company
           , ConsigneeKey     = ORD.ConsigneeKey
           , C_Company        = ORD.C_Company
           --, C_Address        = RTRIM(RTRIM(RTRIM(RTRIM(RTRIM( ORD.C_Address1 +' '+ ORD.C_Address2 ) + ' '+ ORD.C_Address3) +' '+ ORD.C_Address4) +' '+ ORD.C_City) +' '+ ORD.C_Country)   --WL01
           , C_Address        = RTRIM(RTRIM(RTRIM(RTRIM(RTRIM( ORD.C_Company +' '+ ORD.C_Address1 ) + ' '+ ORD.C_Address2) +' '+ ORD.C_Address3) +' '+ ORD.C_City) +' '+ ORD.C_Country)   --WL01
           , C_Country        = ORD.C_Country
           , SoldTo           = ORD.SoldTo
           , DeliveryDate     = ORD.DeliveryDate
           , ExternOrderKey   = ORD.ExternOrderKey
           , CarrierAgent     = ORD.CarrierAgent
           , NoOfCtn          = PAK.NoOfCtn
           , SeqNo            = ROW_NUMBER() OVER(PARTITION BY ORD.Loadkey ORDER BY ORD.PickslipNo)   --WL02
           , LFLContactName   = ISNULL( RTRIM( PVHRPT.Description ), '' )
           , LFLContactAddress= ISNULL( RTRIM( PVHRPT.Notes ), '' )
           , LFLContactPhone  = ISNULL( RTRIM( PVHRPT.Long ), '' )
           , MBOLKey          = ORD.MBOLKey   --WL02
      FROM
      (
         SELECT Loadkey          = RTRIM( OH.Loadkey )   --WL02
              , BookingReference = ISNULL( RTRIM( MBOL.BookingReference ), '')
              , PickSlipNo       = ISNULL( RTRIM( ISNULL(PIKHDD.PickheaderKey, PIKHDC.PickheaderKey) ), '')
              , Storerkey        = ISNULL( RTRIM( OH.Storerkey ), '')
              , Company          = ISNULL( RTRIM( ST.Company ), '')
              , ConsigneeKey     = ISNULL( RTRIM( OH.ConsigneeKey ), '')
              --WL01 START
              , C_Company        = CASE WHEN ISNULL(RTRIM( SR.Fax1 ) , '') = '' THEN ISNULL(RTRIM( OH.C_Company ) , '')
                                                                                ELSE ISNULL(RTRIM( SR.B_Company ) , '') END
              , C_Address1       = CASE WHEN ISNULL(RTRIM( SR.Fax1 ) , '') = '' THEN ISNULL(RTRIM( OH.C_Address1 ) , '')
                                                                                ELSE ISNULL(RTRIM( SR.B_Address1 ) , '') END
              , C_Address2       = CASE WHEN ISNULL(RTRIM( SR.Fax1 ) , '') = '' THEN ISNULL(RTRIM( OH.C_Address2 ) , '')
                                                                                ELSE ISNULL(RTRIM( SR.B_Address2 ) , '') END
              , C_Address3       = CASE WHEN ISNULL(RTRIM( SR.Fax1 ) , '') = '' THEN ISNULL(RTRIM( OH.C_Address3 ) , '')
                                                                                ELSE ISNULL(RTRIM( SR.B_Address3 ) , '') END
              , C_Address4       = ISNULL( RTRIM( OH.B_Address4 ), '')
              , C_City           = CASE WHEN ISNULL(RTRIM( SR.Fax1 ) , '') = '' THEN ISNULL(RTRIM( OH.C_City ) , '')
                                                                                ELSE ISNULL(RTRIM( SR.B_City ) , '') END
              , C_Country        = CASE WHEN ISNULL(RTRIM( SR.Fax1 ) , '') = '' THEN ISNULL(RTRIM( OH.C_State ) , '')
                                                                                ELSE ISNULL(RTRIM( SR.B_Country ) , '') END
              --WL01 END
              , SoldTo           = ISNULL( RTRIM( OH.BillToKey ), '') +' '+ ISNULL( RTRIM( IIF(OH.Type IN ('L','R'), ST.Company, BT.Company) ), '')
              , DeliveryDate     = OH.DeliveryDate
              , ExternOrderKey   = ISNULL( RTRIM( CASE WHEN PIKHDD.PickheaderKey IS NULL THEN OH.Loadkey ELSE OH.ExternOrderKey END ), '')
              , CarrierAgent     = ISNULL( RTRIM( MBOL.CarrierAgent ), '')
              , SeqNo            = ROW_NUMBER() OVER(PARTITION BY ISNULL(PIKHDD.PickheaderKey, PIKHDC.PickheaderKey) ORDER BY OH.Orderkey)
              , MBOLKey          = OH.MBOLKey   --WL02
         FROM dbo.ORDERS OH (NOLOCK)
         JOIN dbo.MBOL MBOL (NOLOCK) ON OH.MBOLKey = MBOL.MBOLKey
         JOIN dbo.STORER ST (NOLOCK) ON (ST.Storerkey = OH.Storerkey)
         LEFT JOIN dbo.PICKHEADER PIKHDD (NOLOCK) ON PIKHDD.Orderkey = OH.Orderkey AND PIKHDD.Orderkey<>''
         LEFT JOIN dbo.PICKHEADER PIKHDC (NOLOCK) ON PIKHDC.ExternOrderkey = OH.Loadkey AND PIKHDC.ExternOrderkey<>'' AND ISNULL(PIKHDC.Orderkey,'')=''
         LEFT JOIN dbo.STORER     BT     (NOLOCK) ON OH.BillToKey = BT.Storerkey AND BT.[Type]='2'
         LEFT JOIN dbo.STORER     SR     (NOLOCK) ON SR.Storerkey = 'QHW-' + LTRIM(RTRIM(OH.ConsigneeKey)) AND SR.ConsigneeFor = @c_storerkey AND SR.[Type] = '2'   --WL01   --WL02
         WHERE OH.Storerkey  = @c_storerkey
          --AND (ISNULL(:as_mbolkey,'')<>'' AND OH.MBOLKey 
         AND (MBOL.MBOLKey IN (SELECT LTRIM(ColValue) FROM dbo.fnc_DelimSplit(',',replace(@c_Mbolkey,char(13)+char(10),',')) WHERE ColValue <> ''))
      ) ORD
      LEFT JOIN (
         SELECT PickSlipNo     = PD.PickSlipNo
              , NoOfCtn        = COUNT( DISTINCT PD.LabelNo )
              , MBOLKey        = MD.MBOLKey   --WL02
         FROM PACKDETAIL PD (NOLOCK)
         JOIN PICKDETAIL PIDET (NOLOCK) ON PD.LabelNo = PIDET.CaseID AND PD.StorerKey = PIDET.Storerkey   --WL02
         JOIN MBOLDETAIL MD (NOLOCK) ON MD.OrderKey = PIDET.OrderKey   --WL02
         WHERE PD.Storerkey = @c_storerkey
         GROUP BY PD.PickSlipNo, MD.MBOLKey   --WL02
      ) PAK
      ON ORD.PickSlipNo = PAK.PickSlipNo AND ORD.MBOLKey = PAK.MBOLKey   --WL02
      
      LEFT JOIN dbo.CodeLkup PVHRPT(NOLOCK) ON PVHRPT.Listname='PVHREPORT' AND PVHRPT.Storerkey=ORD.Storerkey AND PVHRPT.Code='LFL' AND PVHRPT.Code2=''
      
      WHERE ORD.SeqNo = 1
   ) X
   GROUP BY X.Loadkey, FLOOR((X.SeqNo-1)/2)   --WL02

QUIT_SP:
   IF @n_Continue=3  -- Error Occured - Process And Return  
   BEGIN  
      SET @b_Success = 0  
      IF  @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt  
      BEGIN  
         ROLLBACK TRAN  
      END  
      ELSE  
      BEGIN  
         WHILE @@TRANCOUNT > @n_StartTCnt  
         BEGIN  
            COMMIT TRAN  
         END  
      END  
  
      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'isp_delivery_note43_rpt'  
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012  
   END  
   ELSE  
   BEGIN  
      SET @b_Success = 1  
      WHILE @@TRANCOUNT > @n_StartTCnt  
      BEGIN  
         COMMIT TRAN  
      END  
   END  
    
   WHILE @@TRANCOUNT < @n_StartTCnt   
      BEGIN TRAN;     
  
END

GO