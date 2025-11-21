SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/      
/* Store Procedure:  isp_GetDmanifest_Dsum10                            */      
/* Creation Date:04-AUG-2022                                            */      
/* Copyright: IDS                                                       */      
/* Written by: CSCHONG                                                  */      
/*                                                                      */      
/* Purpose:  WMS-20362 CN NIKE_18467_POD - CR                           */      
/*                                                                      */      
/* Input Parameters: mbolkey                                            */      
/*                                                                      */      
/* Output Parameters:                                                   */      
/*                                                                      */      
/* Usage:                                                               */      
/*                                                                      */      
/* Called By:  r_dw_dmanifest_sum10                                     */     
/*             Duplicate From r_dw_dmanifest_sum03                      */ 
/*                                                                      */      
/* PVCS Version: 1.1                                                    */      
/*                                                                      */      
/* Version: 5.4                                                         */      
/*                                                                      */      
/* Data Modifications:                                                  */      
/*                                                                      */      
/* Updates:                                                             */      
/* Date         Author   Ver  Purposes                                  */      
/* 04-08-2022   CSCHONG  1.0  Devops Scripts Combine                    */ 
/* 19-08-2022   Mingle   1.1  WMS-20532 - Modify logic(ML01)            */
/************************************************************************/      
      
CREATE PROC [dbo].[isp_GetDmanifest_Dsum10] (      
         @c_mbolKey      NVARCHAR(20)       
        ,@c_Zone         NVARCHAR(20)      
)      
AS      
BEGIN      
      
   SET NOCOUNT ON      
   SET ANSI_NULLS OFF      
   SET QUOTED_IDENTIFIER OFF      
   SET CONCAT_NULL_YIELDS_NULL OFF      
      
      
 DECLARE  @n_cntRefno           INT                              
         ,@c_site               NVARCHAR(30)                   
         ,@c_storerkey          NVARCHAR(20)                    
         ,@c_qtyPick            int         
         ,@c_qtyPack            int         
         ,@n_err                INT        
         ,@c_CodeCityLdTime     NVARCHAR(30) = 'CityLdTime'   
         ,@c_facility           NVARCHAR(20)
         ,@c_PrefixPsn          NVARCHAR(4)  
           
   SET @n_err = 0         

     SELECT @c_storerkey =Storerkey    
           ,@c_facility = Facility  
      FROM ORDERS WITH (NOLOCK)      
      WHERE mbolkey = @c_mbolKey  


     SET @c_PrefixPsn =''
    SELECT @c_PrefixPsn = ISNULL(C.short,'')
    FROM CODELKUP C WITH (NOLOCK)
    WHERE C.LISTNAME='NKPLANTCD' AND C.CODE = @c_facility
    AND C.Storerkey = @c_Storerkey
      
   IF ISNULL(@c_Zone,'') <> ''      
   BEGIN         
      SELECT  SUM(b.Qty) pick_qty,      
              a.LOADKEY pick_load       
      INTO #tmp_PICKQTYBYLOAD       
      FROM dbo.ORDERS (nolock) a        
      JOIN dbo.PICKDETAIL (nolock) b ON a.OrderKey=b.OrderKey   
      JOIN loc (nolock) c ON b.Loc=c.Loc      
      JOIN dbo.CODELKUP (nolock) d ON c.PickZone=d.code2      
      WHERE a.MBOLKey=@c_mbolKey AND D.Code=@c_Zone       
      AND d.LISTNAME='allsorting' AND a.StorerKey=d.Storerkey      
      GROUP BY a.LOADKEY      
      
      SELECT LoadKey,      
             PickSlipNo      
      INTO #tmp_loadPSN      
      FROM dbo.PackHeader (nolock)       
      WHERE LoadKey IN (SELECT LoadKey from orders (NOLOCK) WHERE MBOLKey=@c_mbolKey)      
      
      SELECT SUM(cc.Qty) pack_qty ,aa.LOADKEY pack_load       
      INTO #tmp_PACKQTYBYLOAD       
      FROM dbo.#tmp_loadPSN (nolock) aa       
      jOIN dbo.PackDetail (nolock)  cc ON aa.PickSlipNo=cc.PickSlipNo       
      WHERE CC.RefNo=@c_Zone      
      GROUP BY aa.LOADKEY ,aa.LOADKEY      
        
   
      SET @n_cntRefno = 1               
          
      SELECT ISNULL(COUNT(DISTINCT c.code),1) AS cntRefno,      
             dbo.ORDERS.LoadKey AS loadkey       
      INTO #tmp_byload      
      FROM  MBOL (NOLOCK)       
      JOIN ORDERS (NOLOCK)ON (MBOL.Mbolkey = Orders.Mbolkey)      
      LEFT JOIN PICKDETAIL PD (NOLOCK) ON PD.orderkey = ORDERS.OrderKey      
      LEFT JOIN LOC L WITH (NOLOCK) ON L.loc=pd.Loc      
      LEFT JOIN CODELKUP C WITH (NOLOCK) ON C.listname = 'ALLSorting' AND      
                                            C.Storerkey=ORDERS.StorerKey AND C.code2=L.PickZone       
      WHERE ( MBOL.MbolKey = @c_mbolKey)      
      GROUP BY dbo.ORDERS.LoadKey        

      
         
      SELECT DISTINCT CASE WHEN  bb.pick_qty=cc.pack_qty THEN MBOL.AddWho ELSE '' END ,         
         CASE WHEN  bb.pick_qty=cc.pack_qty THEN MBOL.MbolKey ELSE '' END ,      
         CASE WHEN  bb.pick_qty=cc.pack_qty THEN MBOL.BookingReference ELSE '' END,         
         CASE WHEN  bb.pick_qty=cc.pack_qty THEN MBOL.OtherReference ELSE '' END,         
         CASE WHEN  bb.pick_qty=cc.pack_qty THEN MBOL.PlaceOfLoading ELSE '' END,         
         CASE WHEN  bb.pick_qty=cc.pack_qty THEN MBOL.PlaceOfDischarge ELSE '' END,         
         CASE WHEN  bb.pick_qty=cc.pack_qty THEN MBOL.EffectiveDate ELSE '' END,         
         CASE WHEN  bb.pick_qty=cc.pack_qty THEN MBOL.CarrierKey ELSE '' END,         
         CASE WHEN  bb.pick_qty=cc.pack_qty THEN MBOL.Vessel ELSE '' END,         
         CASE WHEN  bb.pick_qty=cc.pack_qty THEN MBOL.VoyageNumber ELSE '' END,         
         CASE WHEN  bb.pick_qty=cc.pack_qty THEN MBOL.DRIVERName ELSE '' END,         
         CASE WHEN  bb.pick_qty=cc.pack_qty THEN MBOL.Editdate ELSE '' END ,        
         CASE WHEN  bb.pick_qty=cc.pack_qty THEN ORDERS.ConsigneeKey ELSE '' END ,         
         CASE WHEN  bb.pick_qty=cc.pack_qty THEN ORDERS.ExternOrderKey ELSE ''  END,        
         CASE WHEN  bb.pick_qty=cc.pack_qty THEN ORDERS.C_Address1 ELSE ''  END,      
         CASE WHEN  bb.pick_qty=cc.pack_qty THEN ORDERS.C_Address2 ELSE '' END ,      
         CASE WHEN  bb.pick_qty=cc.pack_qty THEN ORDERS.C_Address3 ELSE '' END,      
         CASE WHEN  bb.pick_qty=cc.pack_qty THEN ORDERS.C_Address4 ELSE '' END,      
         CASE WHEN  bb.pick_qty=cc.pack_qty THEN ORDERS.C_Contact1 ELSE '' END ,      
         CASE WHEN  bb.pick_qty=cc.pack_qty THEN ORDERS.C_Contact2 ELSE ''  END,      
         CASE WHEN  bb.pick_qty=cc.pack_qty THEN ORDERS.C_Phone1 ELSE ''END ,      
         CASE WHEN  bb.pick_qty=cc.pack_qty THEN ORDERS.C_Phone2 ELSE '' END,      
         CASE WHEN  bb.pick_qty=cc.pack_qty THEN ORDERS.C_Fax1 ELSE '' END,      
         CASE WHEN  bb.pick_qty=cc.pack_qty THEN ORDERS.C_Fax2 ELSE ''END ,      
         CASE WHEN TBL.cntRefno>1 THEN  @c_Zone + '-' + ORDERS.Loadkey ELSE ORDERS.Loadkey END AS loadkey,     
         CASE WHEN  bb.pick_qty=cc.pack_qty THEN ORDERS.DeliveryDate ELSE '' END,      
         CASE WHEN  bb.pick_qty=cc.pack_qty THEN ORDERS.Grossweight ELSE ''END ,      
         CASE WHEN  bb.pick_qty=cc.pack_qty THEN ORDERS.Capacity ELSE ''END ,       
         CASE WHEN  bb.pick_qty=cc.pack_qty THEN ORDERS.Loadkey ELSE '' END AS OHLOAD,  
         CASE WHEN  bb.pick_qty=cc.pack_qty THEN MBOL.Facility ELSE '' END,      
         1 AS CartonNo,      
         '' AS Pickslipno,      
         '' AS pickzone,      
         '0' AS FWQTY,      
         '0' AS APPQTY,      
         '0' AS EQQTY,      
         --CASE WHEN  bb.pick_qty=cc.pack_qty THEN Orders.C_Company ELSE '' END,  
			CASE WHEN  bb.pick_qty=cc.pack_qty AND ORDERS.type IN ('ZS05','ZS06') THEN Orders.M_Company
		        WHEN  bb.pick_qty=cc.pack_qty AND ORDERS.type NOT IN ('ZS05','ZS06') THEN Orders.C_Company ELSE '' END,	--ML01
         ETA = CASE WHEN  bb.pick_qty=cc.pack_qty THEN      
              (CASE WHEN ISNULL(STORER.SUSR1,'') = 'CRD' THEN         
              (             
                CASE WHEN (CLC1.Short IS NULL) AND ORDERS.StorerKey = 'NIKECN' THEN MBOL.EditDate    
                     WHEN ISDATE(ORDERS.Userdefine10) = 1 AND (ISNUMERIC(ISNULL(ORDERS.Userdefine01,'0')) = 1 OR ISNUMERIC(ISNULL(CLC1.Short,'0')) = 1) AND ISDATE(ORDERS.DeliveryDate) = 0       
                     THEN DATEADD(DAY, CONVERT(INT, CASE WHEN CLC1.Short IS NULL THEN ISNULL(ORDERS.Userdefine01,'0') ELSE ISNULL(CLC1.Short,'0') END), CONVERT(DATETIME, ORDERS.Userdefine10))        
                     WHEN ISDATE(ORDERS.Userdefine10) = 1 AND (ISNUMERIC(ISNULL(ORDERS.Userdefine01,'0')) = 1 OR ISNUMERIC(ISNULL(CLC1.Short,'0')) = 1) AND ISDATE(ORDERS.DeliveryDate) = 1         
                     THEN CASE WHEN DATEADD(DAY, CONVERT(INT, CASE WHEN CLC1.Short IS NULL THEN ISNULL(ORDERS.Userdefine01,'0') ELSE ISNULL(CLC1.Short,'0') END), CONVERT(DATETIME, ORDERS.Userdefine10))       
                                    >= CONVERT(DATETIME, ORDERS.DeliveryDate)   
                               THEN DATEADD(DAY, CONVERT(INT, CASE WHEN CLC1.Short IS NULL THEN ISNULL(ORDERS.Userdefine01,'0') ELSE ISNULL(CLC1.Short,'0') END), CONVERT(DATETIME, ORDERS.Userdefine10))          
                               ELSE CONVERT(DATETIME, ORDERS.DeliveryDate)     
                               END        
                     WHEN (CLC.Short IS NULL OR ISNUMERIC(CLC.Short) <> 1) AND ORDERS.StorerKey <> 'NIKECN' THEN MBOL.EditDate         
                     ELSE CASE WHEN Orders.Intermodalvehicle = 'ILOE'     
                               THEN DATEADD(HOUR, CEILING(CAST(CLC.Short AS REAL)), CONVERT(DATETIME,CONVERT(CHAR(8),MBOL.EditDate,112))+1)      
                               ELSE CASE WHEN ORDERS.Storerkey = 'NIKECN' THEN DATEADD(DAY, CEILING(CAST(CLC1.Short AS REAL)), MBOL.EditDate )         
                                                                          ELSE DATEADD(DAY, CEILING(CAST(CLC.Short AS REAL)), MBOL.EditDate ) END     
                               END      
                END      
              )       
                   ELSE DATEADD(DAY, CONVERT(INT, CASE WHEN CLC1.Short IS NULL THEN ISNULL(ORDERS.Userdefine01,'0') ELSE ISNULL(CLC1.Short,'0') END), CONVERT(DATETIME, ORDERS.Userdefine10))END) ELSE '' END,             
         CASE WHEN  bb.pick_qty=cc.pack_qty THEN CASE WHEN ISNULL(CLR5.Short,'N') = 'Y' THEN LTRIM(RTRIM(ISNULL(ORDERS.C_contact1,''))) + ' ' + LTRIM(RTRIM(ISNULL(ORDERS.C_Phone1,'')))   
                                                                                        ELSE CAST(ORDERS.Notes AS CHAR(255)) END     
                                            ELSE '' END AS Notes,       
         CASE WHEN  bb.pick_qty=cc.pack_qty THEN  ISNULL(RTRIM(CAST(STORER.notes1 AS CHAR(255))), '') + SPACE(1) + ISNULL(RTRIM(CAST(STORER.notes2 AS CHAR(255))),'') ELSE '' END AS Remarks,              
         CASE WHEN  bb.pick_qty=cc.pack_qty THEN ORDERS.C_City ELSE '' END,      
         CASE WHEN  bb.pick_qty=cc.pack_qty THEN Orders.intermodalvehicle ELSE '' END,       
         CASE WHEN  bb.pick_qty=cc.pack_qty THEN CODELKUP.Short ELSE '' END AS Domain,      
         ShowField = CASE WHEN bb.pick_qty=cc.pack_qty THEN (CASE WHEN ISNULL(CLR.Code,'') <> '' THEN 'Y' ELSE 'N' END) ELSE '' END  ,      
         ShowCRD  = CASE WHEN  bb.pick_qty=cc.pack_qty THEN (CASE WHEN ((ISNULL(STORER.SUSR1,'') = 'CRD' AND ISNULL(ORDERS.userdefine10,'') <> ''      
                    AND (CONVERT(NVARCHAR(10),(CONVERT(DATETIME,ORDERS.userdefine10) +     
                    CONVERT(INT,CASE WHEN CLC1.Short IS NULL AND ORDERS.StorerKey = 'NIKECN' THEN 0 WHEN CLC1.Short IS NULL THEN ORDERS.Userdefine01 ELSE CLC1.Short END)),121))      
                    <  CONVERT(NVARCHAR(10),ORDERS.DeliveryDate,121))) THEN             
            'Y' ELSE 'N' END      
            ) ELSE '' END,      
         CASE WHEN  bb.pick_qty=cc.pack_qty THEN  CONVERT(NVARCHAR(10),ORDERS.DeliveryDate,121) ELSE '' END CRD,     
         LP = CASE WHEN  bb.pick_qty=cc.pack_qty THEN ( CASE WHEN @c_Zone = 'CRW'  THEN CASE WHEN ISNULL(CLR7.Notes,'') <> '' THEN CLR7.Notes ELSE CLR2.NOTES2   END        
                                                             WHEN @c_Zone = 'CRWP' THEN CASE WHEN ISNULL(CLR7.Notes,'') <> '' THEN CLR7.Notes ELSE CLR2.NOTES    END        
                                                             WHEN @c_Zone = 'ECTR' THEN CASE WHEN ISNULL(CLR7.Notes,'') <> '' THEN CLR7.Notes ELSE CLR2.NOTES2   END        
                                                             ELSE CASE WHEN ISNULL(CLR7.Notes,'') <> '' THEN CLR7.Notes ELSE '' END END ) ELSE '' END,         
         CT = CASE WHEN  bb.pick_qty=cc.pack_qty THEN ( CASE WHEN @c_Zone = 'CRW'  THEN CASE WHEN ISNULL(CLR8.Notes,'') <> '' THEN CLR8.Notes ELSE CLR1.NOTES2   END          
                                                             WHEN @c_Zone = 'CRWP' THEN CASE WHEN ISNULL(CLR8.Notes,'') <> '' THEN CLR8.Notes ELSE CLR1.NOTES    END        
                                                             WHEN @c_Zone = 'ECTR' THEN CASE WHEN ISNULL(CLR8.Notes,'') <> '' THEN CLR8.Notes ELSE CLR1.NOTES2   END        
                                                             ELSE CASE WHEN ISNULL(CLR8.Notes,'') <> '' THEN CLR8.Notes ELSE '' END END ) ELSE '' END,         
         TL = CASE WHEN  bb.pick_qty=cc.pack_qty THEN ( CASE WHEN @c_Zone = 'CRW'  THEN CASE WHEN ISNULL(CLR9.Notes,'') <> '' THEN CLR9.Notes ELSE CLR3.NOTES2   END        
                                                             WHEN @c_Zone = 'CRWP' THEN CASE WHEN ISNULL(CLR9.Notes,'') <> '' THEN CLR9.Notes ELSE CLR3.NOTES    END        
                                                             WHEN @c_Zone = 'ECTR' THEN CASE WHEN ISNULL(CLR9.Notes,'') <> '' THEN CLR9.Notes ELSE CLR3.NOTES2   END        
                                                             ELSE CASE WHEN ISNULL(CLR9.Notes,'') <> '' THEN CLR9.Notes ELSE '' END END ) ELSE '' END,           
         FX = CASE WHEN  bb.pick_qty=cc.pack_qty THEN ( CASE WHEN @c_Zone = 'CRW'  THEN CASE WHEN ISNULL(CLR10.Notes,'') <> '' THEN CLR10.Notes ELSE CLR4.NOTES2 END          
                                                             WHEN @c_Zone = 'CRWP' THEN CASE WHEN ISNULL(CLR10.Notes,'') <> '' THEN CLR10.Notes ELSE CLR4.NOTES  END        
                                                             WHEN @c_Zone = 'ECTR' THEN CASE WHEN ISNULL(CLR10.Notes,'') <> '' THEN CLR10.Notes ELSE CLR4.NOTES2 END        
                                                             ELSE CASE WHEN ISNULL(CLR10.Notes,'') <> '' THEN CLR10.Notes ELSE '' END END ) ELSE '' END,       
         [SITE] = @c_Zone,                                              
         CASE WHEN ISNULL(CLR5.Short,'N') = 'Y' THEN (SELECT TOP 1 ISNULL(CL.Description,'')     
                                                      FROM CODELKUP CL (NOLOCK)     
                                                      WHERE CL.LISTNAME = 'RDATA' AND CL.Code = '001') ELSE '' END AS O2,    
         ISNULL(CLR5.Short,'N'),    
         ORDERS.ExternPOKey,    
         CASE WHEN ISNULL(CLR6.Short,'N') = 'Y' AND ISNUMERIC(CLC.Short) = 1 THEN CONVERT(NVARCHAR(30), DATEADD(d,CAST(CLC.Short AS INT),MBOL.AddDate), 121) ELSE NULL END AS NewETA,    
         @c_PrefixPsn AS PrefixPsn,
         ORDERS.DeliveryDate   
      FROM MBOL (NOLOCK)      
      JOIN MBOLDETAIL (NOLOCK) ON (MBOL.Mbolkey = MBOLDETAIL.Mbolkey )         
      JOIN ORDERS (NOLOCK)ON (MBOLDETAIL.Orderkey = Orders.Orderkey)      
      LEFT OUTER JOIN PICKHEADER (NOLOCK) ON (ORDERS.Loadkey = PICKHEADER.ExternOrderkey)      
      LEFT OUTER JOIN CODELKUP CLC (NOLOCK) ON (CLC.LONG = ORDERS.Facility AND       
                                                CLC.Description = ORDERS.c_City AND      
                                                CLC.ListName = @c_CodeCityLdTime AND        
                                                CAST(CLC.Notes AS CHAR(30)) = Orders.intermodalvehicle)          
      LEFT OUTER JOIN CODELKUP CLC1 (NOLOCK) ON (CLC1.LONG = ORDERS.Facility AND       
                                                 CLC1.[Description] = ORDERS.C_City AND      
                                                 CLC1.ListName = @c_CodeCityLdTime AND    
                                                 CLC1.Storerkey = ORDERS.StorerKey)        
      LEFT OUTER JOIN CODELKUP (NOLOCK) ON (CODELKUP.Listname = 'STRDOMAIN' AND      
                                            CODELKUP.Code = ORDERS.StorerKey)       
      LEFT OUTER JOIN STORER (NOLOCK) ON (STORER.StorerKey = ORDERS.ConsigneeKey)      
      LEFT OUTER JOIN Codelkup CLR (NOLOCK) ON (ORDERS.Storerkey = CLR.Storerkey AND CLR.Code = 'SHOWFIELD'                                              
                                            AND CLR.Listname = 'REPORTCFG' AND CLR.Long = 'r_dw_dmanifest_sum10' AND ISNULL(CLR.Short,'') <> 'N')      
      LEFT OUTER JOIN CODELKUP CLR1 (NOLOCK) ON (ORDERS.Storerkey = CLR1.Storerkey AND CLR1.Listname = 'REPORTCFG'        
                                             AND CLR1.Long = 'r_dw_dmanifest_sum10' AND CLR1.Code = 'ShowCTName' AND ISNULL(CLR1.Short,'') <> 'N')      
      LEFT OUTER JOIN CODELKUP CLR2 (NOLOCK) ON (ORDERS.Storerkey = CLR2.Storerkey AND CLR2.Listname = 'REPORTCFG'        
                                             AND CLR2.Long = 'r_dw_dmanifest_sum10' AND CLR2.Code = 'ShowLPName' AND ISNULL(CLR2.Short,'') <> 'N')      
      LEFT OUTER JOIN CODELKUP CLR3 (NOLOCK) ON (ORDERS.Storerkey = CLR3.Storerkey AND CLR3.Listname = 'REPORTCFG'        
                                             AND CLR3.Long = 'r_dw_dmanifest_sum10' AND CLR3.Code = 'ShowTLName' AND ISNULL(CLR3.Short,'') <> 'N')      
      LEFT OUTER JOIN CODELKUP CLR4 (NOLOCK) ON (ORDERS.Storerkey = CLR4.Storerkey AND CLR4.Listname = 'REPORTCFG'        
                                             AND CLR4.Long = 'r_dw_dmanifest_sum10' AND CLR4.Code = 'ShowFXName' AND ISNULL(CLR4.Short,'') <> 'N')           
      LEFT OUTER JOIN CODELKUP CLR5 (NOLOCK) ON (ORDERS.Storerkey = CLR5.Storerkey AND CLR5.Listname = 'REPORTCFG'        
                                             AND CLR5.Long = 'r_dw_dmanifest_sum10' AND CLR5.Code = 'ShowStorerCols' AND ISNULL(CLR5.Short,'') <> 'N')     
                AND CLR5.Code2 = ORDERS.Facility      
      LEFT OUTER JOIN CODELKUP CLR6 (NOLOCK) ON (ORDERS.Storerkey = CLR6.Storerkey AND CLR6.Listname = 'REPORTCFG'        
                                             AND CLR6.Long = 'r_dw_dmanifest_sum10' AND CLR6.Code = 'ShowNewETA' AND ISNULL(CLR6.Short,'') <> 'N')      
                                             AND CLR6.Code2 = ORDERS.Facility         
      LEFT OUTER JOIN CODELKUP CLR7 (NOLOCK) ON (ORDERS.Storerkey = CLR7.Storerkey AND CLR7.Listname = 'NIKESITE'        
                                             AND CLR7.UDF01 = @c_Zone AND CLR7.Short IN ('LP')    
                                             AND CLR7.Code2 = ORDERS.Facility)      
      LEFT OUTER JOIN CODELKUP CLR8 (NOLOCK) ON (ORDERS.Storerkey = CLR8.Storerkey AND CLR8.Listname = 'NIKESITE'        
                                             AND CLR8.UDF01 = @c_Zone AND CLR8.Short IN ('CT')    
                                             AND CLR8.Code2 = ORDERS.Facility)      
      LEFT OUTER JOIN CODELKUP CLR9 (NOLOCK) ON (ORDERS.Storerkey = CLR9.Storerkey AND CLR9.Listname = 'NIKESITE'        
                                             AND CLR9.UDF01 = @c_Zone AND CLR9.Short IN ('TL')    
                                             AND CLR9.Code2 = ORDERS.Facility)      
      LEFT OUTER JOIN CODELKUP CLR10 (NOLOCK) ON (ORDERS.Storerkey = CLR10.Storerkey AND CLR10.Listname = 'NIKESITE'        
                                             AND CLR10.UDF01 = @c_Zone AND CLR10.Short IN ('FX')    
                                             AND CLR10.Code2 = ORDERS.Facility)        
      LEFT JOIN #tmp_byload TBL ON orders.LoadKey=TBL.loadkey              
      LEFT JOIN #tmp_PICKQTYBYLOAD bb ON orders.LoadKey=bb.pick_load       
      LEFT JOIN #tmp_PACKQTYBYLOAD cc ON orders.LoadKey=cc.pack_load                                                      
      WHERE ( MBOL.MbolKey = @c_mbolKey)          
      AND   PICKHEADER.Pickheaderkey IS NULL      
      UNION ALL      
      SELECT DISTINCT CASE WHEN  bb.pick_qty=cc.pack_qty THEN MBOL.AddWho ELSE ''  END,         
         CASE WHEN  bb.pick_qty=cc.pack_qty THEN MBOL.MbolKey ELSE ''  END,         
         CASE WHEN  bb.pick_qty=cc.pack_qty THEN MBOL.BookingReference ELSE ''  END,         
         CASE WHEN  bb.pick_qty=cc.pack_qty THEN MBOL.OtherReference ELSE ''  END,         
         CASE WHEN  bb.pick_qty=cc.pack_qty THEN MBOL.PlaceOfLoading ELSE ''  END,         
         CASE WHEN  bb.pick_qty=cc.pack_qty THEN MBOL.PlaceOfDischarge ELSE ''  END,         
         CASE WHEN  bb.pick_qty=cc.pack_qty THEN MBOL.EffectiveDate ELSE ''  END,         
         CASE WHEN  bb.pick_qty=cc.pack_qty THEN MBOL.CarrierKey ELSE ''  END,         
         CASE WHEN  bb.pick_qty=cc.pack_qty THEN MBOL.Vessel ELSE ''  END,         
         CASE WHEN  bb.pick_qty=cc.pack_qty THEN MBOL.VoyageNumber ELSE ''  END,         
         CASE WHEN  bb.pick_qty=cc.pack_qty THEN MBOL.DRIVERName ELSE ''  END,         
         CASE WHEN  bb.pick_qty=cc.pack_qty THEN MBOL.Editdate ELSE ''  END,        
         CASE WHEN  bb.pick_qty=cc.pack_qty THEN ORDERS.ConsigneeKey ELSE ''  END,         
         CASE WHEN  bb.pick_qty=cc.pack_qty THEN ORDERS.ExternOrderKey ELSE ''  END,        
         CASE WHEN  bb.pick_qty=cc.pack_qty THEN ORDERS.C_Address1 ELSE ''  END,      
         CASE WHEN  bb.pick_qty=cc.pack_qty THEN ORDERS.C_Address2 ELSE ''  END,      
         CASE WHEN  bb.pick_qty=cc.pack_qty THEN ORDERS.C_Address3 ELSE ''  END,      
         CASE WHEN  bb.pick_qty=cc.pack_qty THEN ORDERS.C_Address4 ELSE ''  END,      
         CASE WHEN  bb.pick_qty=cc.pack_qty THEN ORDERS.C_Contact1 ELSE ''  END,      
         CASE WHEN  bb.pick_qty=cc.pack_qty THEN ORDERS.C_Contact2 ELSE ''  END,      
         CASE WHEN  bb.pick_qty=cc.pack_qty THEN ORDERS.C_Phone1 ELSE ''  END,      
         CASE WHEN  bb.pick_qty=cc.pack_qty THEN ORDERS.C_Phone2 ELSE ''  END,      
         CASE WHEN  bb.pick_qty=cc.pack_qty THEN ORDERS.C_Fax1 ELSE ''  END,      
         CASE WHEN  bb.pick_qty=cc.pack_qty THEN ORDERS.C_Fax2 ELSE ''  END,      
         CASE WHEN TBL.cntRefno>1 THEN  @c_Zone + '-' + ORDERS.Loadkey ELSE ORDERS.Loadkey END AS loadkey,       
         CASE WHEN  bb.pick_qty=cc.pack_qty THEN ORDERS.DeliveryDate ELSE ''  END,      
         CASE WHEN  bb.pick_qty=cc.pack_qty THEN ORDERS.Grossweight ELSE ''  END,      
         CASE WHEN  bb.pick_qty=cc.pack_qty THEN ORDERS.Capacity ELSE ''  END,       
         CASE WHEN  bb.pick_qty=cc.pack_qty THEN ORDERS.Loadkey  ELSE ''  END AS OHLOAD,  
         CASE WHEN  bb.pick_qty=cc.pack_qty THEN MBOL.Facility ELSE ''  END ,      
         CASE WHEN  bb.pick_qty=cc.pack_qty THEN Packdetail.CartonNo  ELSE ''  END AS CartonNo ,      
         CASE WHEN  bb.pick_qty=cc.pack_qty THEN Packdetail.Pickslipno  ELSE ''  END ,      
         CASE WHEN  bb.pick_qty=cc.pack_qty THEN Pickheader.Zone  ELSE ''  END AS PickZone,      
         (SELECT SUM(packdetail.qty)       
          FROM packdetail(NOLOCK),sku(NOLOCK) WHERE packdetail.Storerkey = sku.Storerkey  AND packdetail.sku = sku.sku AND sku.skugroup = 'FOOTWEAR'      
          AND packdetail.Storerkey =PackHeader.Storerkey AND packdetail.Pickslipno =PackHeader.Pickslipno  AND PACKDETAIL.RefNo = @c_Zone)   AS FWQTY,      
         (SELECT SUM(packdetail.qty)      
          FROM packdetail(NOLOCK),sku(NOLOCK) WHERE packdetail.Storerkey = sku.Storerkey  AND packdetail.sku = sku.sku AND sku.skugroup = 'APPAREL'      
          AND packdetail.Storerkey =PackHeader.Storerkey AND packdetail.Pickslipno =PackHeader.Pickslipno  AND PACKDETAIL.RefNo = @c_Zone)   AS APPQTY,      
         (SELECT SUM(packdetail.qty)       
          FROM packdetail(NOLOCK),sku(NOLOCK) WHERE packdetail.Storerkey = sku.Storerkey  AND packdetail.sku = sku.sku AND sku.skugroup = 'EQUIPMENT'      
          AND packdetail.Storerkey =PackHeader.Storerkey AND packdetail.Pickslipno =PackHeader.Pickslipno  AND PACKDETAIL.RefNo = @c_Zone)   AS EQQTY,      
         --CASE WHEN  bb.pick_qty=cc.pack_qty THEN Orders.C_company ELSE ''  END , 
			CASE WHEN  bb.pick_qty=cc.pack_qty AND ORDERS.type IN ('ZS05','ZS06') THEN Orders.M_Company
		        WHEN  bb.pick_qty=cc.pack_qty AND ORDERS.type NOT IN ('ZS05','ZS06') THEN Orders.C_Company ELSE '' END,	--ML01 
         ETA = CASE WHEN  bb.pick_qty=cc.pack_qty THEN    
               (CASE WHEN ISNULL(STORER.SUSR1,'') = 'CRD' THEN      
         (      
               CASE WHEN (CLC1.Short IS NULL) AND ORDERS.StorerKey = 'NIKECN' THEN MBOL.EditDate    
                    WHEN ISDATE(ORDERS.Userdefine10) = 1 AND (ISNUMERIC(ISNULL(ORDERS.Userdefine01,'0')) = 1 OR ISNUMERIC(ISNULL(CLC1.Short,'0')) = 1) AND ISDATE(ORDERS.DeliveryDate) = 0      
                    THEN DATEADD(DAY, CONVERT(INT, CASE WHEN CLC1.Short IS NULL THEN ISNULL(ORDERS.Userdefine01,'0') ELSE ISNULL(CLC1.Short,'0') END), CONVERT(DATETIME, ORDERS.Userdefine10))        
                    WHEN ISDATE(ORDERS.Userdefine10) = 1 AND (ISNUMERIC(ISNULL(ORDERS.Userdefine01,'0')) = 1 OR ISNUMERIC(ISNULL(CLC1.Short,'0')) = 1) AND ISDATE(ORDERS.DeliveryDate) = 1      
                    THEN CASE WHEN DATEADD(DAY, CONVERT(INT, CASE WHEN CLC1.Short IS NULL THEN ISNULL(ORDERS.Userdefine01,'0') ELSE ISNULL(CLC1.Short,'0') END), CONVERT(DATETIME, ORDERS.Userdefine10))       
                                   >= CONVERT(DATETIME, ORDERS.DeliveryDate)     
                              THEN DATEADD(DAY, CONVERT(INT, CASE WHEN CLC1.Short IS NULL THEN ISNULL(ORDERS.Userdefine01,'0') ELSE ISNULL(CLC1.Short,'0') END), CONVERT(DATETIME, ORDERS.Userdefine10))     
                              ELSE CONVERT(DATETIME, ORDERS.DeliveryDate)   
                              END        
                    WHEN (CLC.Short IS NULL OR ISNUMERIC(CLC.Short) <> 1) AND ORDERS.StorerKey <> 'NIKECN' THEN MBOL.EditDate         
                              ELSE CASE WHEN Orders.Intermodalvehicle = 'ILOE'     
                              THEN DATEADD(HOUR, CEILING(CAST(CLC.Short AS REAL)), CONVERT(DATETIME,CONVERT(CHAR(8),MBOL.EditDate,112))+1)      
                              ELSE CASE WHEN ORDERS.Storerkey = 'NIKECN' THEN DATEADD(DAY, CEILING(CAST(CLC1.Short AS REAL)), MBOL.EditDate )          
                                                                         ELSE DATEADD(DAY, CEILING(CAST(CLC.Short AS REAL)), MBOL.EditDate ) END      
                              END      
               END)    
               ELSE DATEADD(DAY, CONVERT(INT, CASE WHEN CLC1.Short IS NULL THEN ISNULL(ORDERS.Userdefine01,'0') ELSE ISNULL(CLC1.Short,'0') END), CONVERT(DATETIME, ORDERS.Userdefine10))END)ELSE '' END  ,
       
         CASE WHEN  bb.pick_qty=cc.pack_qty THEN CASE WHEN ISNULL(CLR5.Short,'N') = 'Y' THEN LTRIM(RTRIM(ISNULL(ORDERS.C_contact1,''))) + ' ' + LTRIM(RTRIM(ISNULL(ORDERS.C_Phone1,'')))    
                                                                                        ELSE CAST(ORDERS.Notes AS CHAR(255)) END    
                                            ELSE '' END AS Notes,       
         CASE WHEN  bb.pick_qty=cc.pack_qty THEN RTRIM(CAST(STORER.notes1 AS CHAR(255))) + SPACE(1) + RTRIM(CAST(STORER.notes2 AS CHAR(255)))  ELSE ''  END AS Remarks,       
         CASE WHEN  bb.pick_qty=cc.pack_qty THEN ORDERS.C_City ELSE ''  END ,       
         CASE WHEN  bb.pick_qty=cc.pack_qty THEN Orders.intermodalvehicle ELSE ''  END ,       
         CASE WHEN  bb.pick_qty=cc.pack_qty THEN CODELKUP.Short ELSE ''  END ,      
         ShowField = CASE WHEN  bb.pick_qty=cc.pack_qty THEN (CASE WHEN ISNULL(CLR.Code,'') <> '' THEN 'Y' ELSE 'N' END) ELSE '' END  ,      
         ShowCRD  = CASE WHEN  bb.pick_qty=cc.pack_qty THEN (CASE WHEN ((ISNULL(STORER.SUSR1,'') = 'CRD' AND ISNULL(ORDERS.userdefine10,'') <> ''      
                    AND (CONVERT(NVARCHAR(10),(CONVERT(DATETIME,ORDERS.userdefine10) +     
                    CONVERT(INT,CASE WHEN CLC1.Short IS NULL AND ORDERS.StorerKey = 'NIKECN' THEN 0 WHEN CLC1.Short IS NULL THEN ORDERS.Userdefine01 ELSE CLC1.Short END)),121))       
                    <  CONVERT(NVARCHAR(10),ORDERS.DeliveryDate,121))) THEN              
            'Y' ELSE 'N' END      
            ) ELSE '' END,            
         CASE WHEN  bb.pick_qty=cc.pack_qty THEN  CONVERT(NVARCHAR(10),ORDERS.DeliveryDate,121) ELSE '' END CRD,                 
         LP = CASE WHEN  bb.pick_qty=cc.pack_qty THEN ( CASE WHEN @c_Zone = 'CRW'  THEN CASE WHEN ISNULL(CLR7.Notes,'') <> '' THEN CLR7.Notes ELSE CLR2.NOTES2   END        
                                                             WHEN @c_Zone = 'CRWP' THEN CASE WHEN ISNULL(CLR7.Notes,'') <> '' THEN CLR7.Notes ELSE CLR2.NOTES    END        
                                                             WHEN @c_Zone = 'ECTR' THEN CASE WHEN ISNULL(CLR7.Notes,'') <> '' THEN CLR7.Notes ELSE CLR2.NOTES2   END        
                                                             ELSE CASE WHEN ISNULL(CLR7.Notes,'') <> '' THEN CLR7.Notes ELSE '' END END ) ELSE '' END,         
         CT = CASE WHEN  bb.pick_qty=cc.pack_qty THEN ( CASE WHEN @c_Zone = 'CRW'  THEN CASE WHEN ISNULL(CLR8.Notes,'') <> '' THEN CLR8.Notes ELSE CLR1.NOTES2   END          
                                                             WHEN @c_Zone = 'CRWP' THEN CASE WHEN ISNULL(CLR8.Notes,'') <> '' THEN CLR8.Notes ELSE CLR1.NOTES    END        
                                WHEN @c_Zone = 'ECTR' THEN CASE WHEN ISNULL(CLR8.Notes,'') <> '' THEN CLR8.Notes ELSE CLR1.NOTES2   END        
                                                             ELSE CASE WHEN ISNULL(CLR8.Notes,'') <> '' THEN CLR8.Notes ELSE '' END END ) ELSE '' END,          
         TL = CASE WHEN  bb.pick_qty=cc.pack_qty THEN ( CASE WHEN @c_Zone = 'CRW'  THEN CASE WHEN ISNULL(CLR9.Notes,'') <> '' THEN CLR9.Notes ELSE CLR3.NOTES2   END        
                                                             WHEN @c_Zone = 'CRWP' THEN CASE WHEN ISNULL(CLR9.Notes,'') <> '' THEN CLR9.Notes ELSE CLR3.NOTES    END        
                      WHEN @c_Zone = 'ECTR' THEN CASE WHEN ISNULL(CLR9.Notes,'') <> '' THEN CLR9.Notes ELSE CLR3.NOTES2   END        
                                                             ELSE CASE WHEN ISNULL(CLR9.Notes,'') <> '' THEN CLR9.Notes ELSE '' END END ) ELSE '' END,              
         FX = CASE WHEN  bb.pick_qty=cc.pack_qty THEN ( CASE WHEN @c_Zone = 'CRW'  THEN CASE WHEN ISNULL(CLR10.Notes,'') <> '' THEN CLR10.Notes ELSE CLR4.NOTES2 END          
                                                             WHEN @c_Zone = 'CRWP' THEN CASE WHEN ISNULL(CLR10.Notes,'') <> '' THEN CLR10.Notes ELSE CLR4.NOTES  END        
                                                             WHEN @c_Zone = 'ECTR' THEN CASE WHEN ISNULL(CLR10.Notes,'') <> '' THEN CLR10.Notes ELSE CLR4.NOTES2 END        
                                                             ELSE CASE WHEN ISNULL(CLR10.Notes,'') <> '' THEN CLR10.Notes ELSE '' END END ) ELSE '' END,     
         [SITE] = @c_Zone,                                                    
         CASE WHEN ISNULL(CLR5.Short,'N') = 'Y' THEN (SELECT TOP 1 ISNULL(CL.Description,'')     
                                                      FROM CODELKUP CL (NOLOCK)     
                                                      WHERE CL.LISTNAME = 'RDATA' AND CL.Code = '001') ELSE '' END AS O2,    
         ISNULL(CLR5.Short,'N') AS ShowStorerCols,    
         ORDERS.ExternPOKey,    
         CASE WHEN ISNULL(CLR6.Short,'N') = 'Y' AND ISNUMERIC(CLC.Short) = 1 THEN CONVERT(NVARCHAR(30), DATEADD(d,CAST(CLC.Short AS INT),MBOL.AddDate), 121) ELSE NULL END AS NewETA,       
         @c_PrefixPsn AS PrefixPsn,
         ORDERS.DeliveryDate   
      FROM MBOL (NOLOCK)      
      JOIN MBOLDETAIL (NOLOCK) ON (MBOL.Mbolkey = MBOLDETAIL.Mbolkey )         
      INNER JOIN ORDERS (NOLOCK)ON (MBOLDETAIL.Orderkey = Orders.Orderkey)      
      INNER JOIN PACKHEADER (NOLOCK) ON (ORDERS.Storerkey = PACKHEADER.Storerkey AND ORDERS.Orderkey = PACKHEADER.Orderkey)      
      INNER JOIN PACKDETAIL (NOLOCK) ON (PACKHEADER.Storerkey = PACKDETAIL.Storerkey AND PACKHEADER.Pickslipno = PACKDETAIL.Pickslipno)       
      INNER JOIN PICKHEADER (NOLOCK) ON (PACKHEADER.Pickslipno = PICKHEADER.Pickheaderkey)      
      LEFT OUTER JOIN CODELKUP CLC (NOLOCK) ON (CLC.LONG = ORDERS.Facility AND       
                                                CLC.Description = ORDERS.c_City AND      
                                                CLC.ListName = @c_CodeCityLdTime AND     
                                                CAST(CLC.Notes AS CHAR(30)) = Orders.intermodalvehicle)         
      LEFT OUTER JOIN CODELKUP CLC1 (NOLOCK) ON (CLC1.LONG = ORDERS.Facility AND       
                                                 CLC1.[Description] = ORDERS.C_City AND      
                                                 CLC1.ListName = @c_CodeCityLdTime AND    
                                                 CLC1.Storerkey = ORDERS.StorerKey)        
      LEFT OUTER JOIN CODELKUP (NOLOCK) ON (CODELKUP.Listname = 'STRDOMAIN' AND      
                                            CODELKUP.Code = ORDERS.StorerKey)      
      LEFT OUTER JOIN STORER (NOLOCK) ON (STORER.StorerKey = ORDERS.ConsigneeKey)      
      LEFT OUTER JOIN Codelkup CLR (NOLOCK) ON (ORDERS.Storerkey = CLR.Storerkey AND CLR.Code = 'SHOWFIELD'                                              
                                          AND CLR.Listname = 'REPORTCFG' AND CLR.Long = 'r_dw_dmanifest_sum10' AND ISNULL(CLR.Short,'') <> 'N')      
      LEFT OUTER JOIN CODELKUP CLR1 (NOLOCK) ON (ORDERS.Storerkey = CLR1.Storerkey AND CLR1.Listname = 'REPORTCFG'        
                                             AND CLR1.Long = 'r_dw_dmanifest_sum10' AND CLR1.Code = 'ShowCTName' AND ISNULL(CLR1.Short,'') <> 'N')      
      LEFT OUTER JOIN CODELKUP CLR2 (NOLOCK) ON (ORDERS.Storerkey = CLR2.Storerkey AND CLR2.Listname = 'REPORTCFG'        
                                             AND CLR2.Long = 'r_dw_dmanifest_sum10' AND CLR2.Code = 'ShowLPName' AND ISNULL(CLR2.Short,'') <> 'N')      
      LEFT OUTER JOIN CODELKUP CLR3 (NOLOCK) ON (ORDERS.Storerkey = CLR3.Storerkey AND CLR3.Listname = 'REPORTCFG'        
                                             AND CLR3.Long = 'r_dw_dmanifest_sum10' AND CLR3.Code = 'ShowTLName' AND ISNULL(CLR3.Short,'') <> 'N')      
      LEFT OUTER JOIN CODELKUP CLR4 (NOLOCK) ON (ORDERS.Storerkey = CLR4.Storerkey AND CLR4.Listname = 'REPORTCFG'        
                                             AND CLR4.Long = 'r_dw_dmanifest_sum10' AND CLR4.Code = 'ShowFXName' AND ISNULL(CLR4.Short,'') <> 'N')          
      LEFT OUTER JOIN CODELKUP CLR5 (NOLOCK) ON (ORDERS.Storerkey = CLR5.Storerkey AND CLR5.Listname = 'REPORTCFG'        
                                             AND CLR5.Long = 'r_dw_dmanifest_sum10' AND CLR5.Code = 'ShowStorerCols' AND ISNULL(CLR5.Short,'') <> 'N')    
                                             AND CLR5.Code2 = ORDERS.Facility        
      LEFT OUTER JOIN CODELKUP CLR6 (NOLOCK) ON (ORDERS.Storerkey = CLR6.Storerkey AND CLR6.Listname = 'REPORTCFG'        
                                             AND CLR6.Long = 'r_dw_dmanifest_sum10' AND CLR6.Code = 'ShowNewETA' AND ISNULL(CLR6.Short,'') <> 'N')      
                                             AND CLR6.Code2 = ORDERS.Facility         
      LEFT OUTER JOIN CODELKUP CLR7 (NOLOCK) ON (ORDERS.Storerkey = CLR7.Storerkey AND CLR7.Listname = 'NIKESITE'        
                                             AND CLR7.UDF01 = @c_Zone AND CLR7.Short IN ('LP')    
                                             AND CLR7.Code2 = ORDERS.Facility)      
      LEFT OUTER JOIN CODELKUP CLR8 (NOLOCK) ON (ORDERS.Storerkey = CLR8.Storerkey AND CLR8.Listname = 'NIKESITE'        
                                             AND CLR8.UDF01 = @c_Zone AND CLR8.Short IN ('CT')    
                                             AND CLR8.Code2 = ORDERS.Facility)      
      LEFT OUTER JOIN CODELKUP CLR9 (NOLOCK) ON (ORDERS.Storerkey = CLR9.Storerkey AND CLR9.Listname = 'NIKESITE'        
                                             AND CLR9.UDF01 = @c_Zone AND CLR9.Short IN ('TL')    
                                             AND CLR9.Code2 = ORDERS.Facility)      
      LEFT OUTER JOIN CODELKUP CLR10 (NOLOCK) ON (ORDERS.Storerkey = CLR10.Storerkey AND CLR10.Listname = 'NIKESITE'        
                                             AND CLR10.UDF01 = @c_Zone AND CLR10.Short IN ('FX')    
                                             AND CLR10.Code2 = ORDERS.Facility)        
      LEFT JOIN #tmp_byload TBL ON orders.LoadKey=TBL.loadkey             
      LEFT JOIN #tmp_PICKQTYBYLOAD bb ON    orders.LoadKey=bb.pick_load       
      LEFT JOIN #tmp_PACKQTYBYLOAD cc ON    orders.LoadKey=cc.pack_load                                                        
      WHERE ( MBOL.MbolKey = @c_mbolKey)      
      AND PACKDETAIL.RefNo = @c_Zone      
      AND PACKDETAIL.StorerKey = @c_storerkey       
      AND   ( RTRIM(PICKHEADER.OrderKey) IS NOT NULL AND RTRIM(PICKHEADER.OrderKey) <> '')       
   UNION ALL      
   SELECT       
         CASE WHEN  bb.pick_qty=cc.pack_qty THEN MBOL.AddWho  ELSE '' END ,         
         CASE WHEN  bb.pick_qty=cc.pack_qty THEN MBOL.MbolKey  ELSE '' END ,         
         CASE WHEN  bb.pick_qty=cc.pack_qty THEN MBOL.BookingReference  ELSE '' END ,         
         CASE WHEN  bb.pick_qty=cc.pack_qty THEN MBOL.OtherReference  ELSE '' END ,         
         CASE WHEN  bb.pick_qty=cc.pack_qty THEN MBOL.PlaceOfLoading  ELSE '' END ,         
         CASE WHEN  bb.pick_qty=cc.pack_qty THEN MBOL.PlaceOfDischarge  ELSE '' END ,         
         CASE WHEN  bb.pick_qty=cc.pack_qty THEN MBOL.EffectiveDate  ELSE '' END ,         
         CASE WHEN  bb.pick_qty=cc.pack_qty THEN MBOL.CarrierKey  ELSE '' END ,         
         CASE WHEN  bb.pick_qty=cc.pack_qty THEN MBOL.Vessel  ELSE '' END ,         
         CASE WHEN  bb.pick_qty=cc.pack_qty THEN MBOL.VoyageNumber  ELSE '' END ,         
         CASE WHEN  bb.pick_qty=cc.pack_qty THEN MBOL.DRIVERName  ELSE '' END ,         
         CASE WHEN  bb.pick_qty=cc.pack_qty THEN MBOL.Editdate  ELSE '' END ,        
         CASE WHEN  bb.pick_qty=cc.pack_qty THEN MAX(ORDERS.ConsigneeKey)  ELSE '' END ,         
         '' AS ExternOrderKey,        
         CASE WHEN  bb.pick_qty=cc.pack_qty THEN MAX(ORDERS.C_Address1)  ELSE '' END ,      
         CASE WHEN  bb.pick_qty=cc.pack_qty THEN MAX(ORDERS.C_Address2)  ELSE '' END ,      
         CASE WHEN  bb.pick_qty=cc.pack_qty THEN MAX(ORDERS.C_Address3)  ELSE '' END ,      
         CASE WHEN  bb.pick_qty=cc.pack_qty THEN MAX(ORDERS.C_Address4)  ELSE '' END ,      
         CASE WHEN  bb.pick_qty=cc.pack_qty THEN MAX(ORDERS.C_Contact1)  ELSE '' END ,      
         CASE WHEN  bb.pick_qty=cc.pack_qty THEN MAX(ORDERS.C_Contact2)  ELSE '' END ,      
         CASE WHEN  bb.pick_qty=cc.pack_qty THEN MAX(ORDERS.C_Phone1)  ELSE '' END ,      
         CASE WHEN  bb.pick_qty=cc.pack_qty THEN MAX(ORDERS.C_Phone2)  ELSE '' END ,      
         CASE WHEN  bb.pick_qty=cc.pack_qty THEN MAX(ORDERS.C_Fax1)  ELSE '' END ,      
         CASE WHEN  bb.pick_qty=cc.pack_qty THEN MAX(ORDERS.C_Fax2)  ELSE '' END ,      
         CASE WHEN TBL.cntRefno>1 THEN  @c_Zone + '-' + ORDERS.Loadkey ELSE ORDERS.Loadkey END AS loadkey,         
         CASE WHEN  bb.pick_qty=cc.pack_qty THEN  MAX(ORDERS.DeliveryDate)  ELSE '' END ,      
         CASE WHEN  bb.pick_qty=cc.pack_qty THEN  SUM(ORDERS.Grossweight)  ELSE '' END ,      
         CASE WHEN  bb.pick_qty=cc.pack_qty THEN SUM(ORDERS.Capacity)  ELSE '' END ,       
         CASE WHEN  bb.pick_qty=cc.pack_qty THEN ORDERS.Loadkey   ELSE '' END AS OHLOAD,      
         CASE WHEN  bb.pick_qty=cc.pack_qty THEN MBOL.Facility  ELSE '' END ,      
         CASE WHEN  bb.pick_qty=cc.pack_qty THEN Packdetail.CartonNo  ELSE ''  END AS CartonNo ,      
         CASE WHEN  bb.pick_qty=cc.pack_qty THEN PackHeader.Pickslipno  ELSE '' END ,      
         CASE WHEN  bb.pick_qty=cc.pack_qty THEN Pickheader.Zone   ELSE '' END ,       
         (SELECT SUM(packdetail.qty)       
          FROM packdetail(NOLOCK),sku(NOLOCK) WHERE packdetail.Storerkey = sku.Storerkey  AND packdetail.sku = sku.sku AND sku.skugroup = 'FOOTWEAR'      
          AND packdetail.Storerkey =PackHeader.Storerkey AND packdetail.Pickslipno =PackHeader.Pickslipno  AND PACKDETAIL.RefNo = @c_Zone )    AS FWQTY,      
         (SELECT SUM(packdetail.qty)      
          FROM packdetail(NOLOCK),sku(NOLOCK) WHERE packdetail.Storerkey = sku.Storerkey  AND packdetail.sku = sku.sku AND sku.skugroup = 'APPAREL'      
          AND packdetail.Storerkey =PackHeader.Storerkey AND packdetail.Pickslipno =PackHeader.Pickslipno  AND PACKDETAIL.RefNo = @c_Zone)    AS APPQTY,      
         (SELECT SUM(packdetail.qty)       
          FROM packdetail(NOLOCK),sku(NOLOCK) WHERE packdetail.Storerkey = sku.Storerkey  AND packdetail.sku = sku.sku AND sku.skugroup = 'EQUIPMENT'      
          AND packdetail.Storerkey =PackHeader.Storerkey AND packdetail.Pickslipno =PackHeader.Pickslipno  AND PACKDETAIL.RefNo = @c_Zone )    AS EQQTY,      
         --CASE WHEN  bb.pick_qty=cc.pack_qty THEN MAX(Orders.C_company)  ELSE '' END , 
			CASE WHEN  bb.pick_qty=cc.pack_qty AND ORDERS.type IN ('ZS05','ZS06') THEN Orders.M_Company
		        WHEN  bb.pick_qty=cc.pack_qty AND ORDERS.type NOT IN ('ZS05','ZS06') THEN Orders.C_Company ELSE '' END,	--ML01
         ETA = CASE WHEN  bb.pick_qty=cc.pack_qty THEN    
               (CASE WHEN ISNULL(STORER.SUSR1,'') = 'CRD' THEN     
         (      
               CASE WHEN (CLC1.Short IS NULL) AND ORDERS.StorerKey = 'NIKECN' THEN MBOL.EditDate     
                    WHEN ISDATE(ORDERS.Userdefine10) = 1 AND (ISNUMERIC(ISNULL(ORDERS.Userdefine01,'0')) = 1 OR ISNUMERIC(ISNULL(CLC1.Short,'0')) = 1) AND ISDATE(ORDERS.DeliveryDate) = 0        
                    THEN DATEADD(DAY, CONVERT(INT, CASE WHEN CLC1.Short IS NULL THEN ISNULL(ORDERS.Userdefine01,'0') ELSE ISNULL(CLC1.Short,'0') END), CONVERT(DATETIME, ORDERS.Userdefine10))            
                   WHEN ISDATE(ORDERS.Userdefine10) = 1 AND (ISNUMERIC(ISNULL(ORDERS.Userdefine01,'0')) = 1 OR ISNUMERIC(ISNULL(CLC1.Short,'0')) = 1) AND ISDATE(ORDERS.DeliveryDate) = 1         
                    THEN CASE WHEN DATEADD(DAY, CONVERT(INT, CASE WHEN CLC1.Short IS NULL THEN ISNULL(ORDERS.Userdefine01,'0') ELSE ISNULL(CLC1.Short,'0') END), CONVERT(DATETIME, ORDERS.Userdefine10))         
                                   >= CONVERT(DATETIME, ORDERS.DeliveryDate)     
                              THEN DATEADD(DAY, CONVERT(INT, CASE WHEN CLC1.Short IS NULL THEN ISNULL(ORDERS.Userdefine01,'0') ELSE ISNULL(CLC1.Short,'0') END), CONVERT(DATETIME, ORDERS.Userdefine10))          
                              ELSE CONVERT(DATETIME, ORDERS.DeliveryDate)     
                              END        
                    WHEN (CLC.Short IS NULL OR ISNUMERIC(CLC.Short) <> 1) AND ORDERS.StorerKey <> 'NIKECN' THEN MBOL.EditDate          
                    ELSE CASE WHEN Orders.Intermodalvehicle = 'ILOE'     
                              THEN DATEADD(HOUR, CEILING(CAST(CLC.Short AS REAL)), CONVERT(DATETIME,CONVERT(CHAR(8),MBOL.EditDate,112))+1)      
                              ELSE CASE WHEN ORDERS.Storerkey = 'NIKECN' THEN DATEADD(DAY, CEILING(CAST(CLC1.Short AS REAL)), MBOL.EditDate )          
                                                                         ELSE DATEADD(DAY, CEILING(CAST(CLC.Short AS REAL)), MBOL.EditDate ) END     
                         END      
               END)    
               ELSE DATEADD(DAY, CONVERT(INT, CASE WHEN CLC1.Short IS NULL THEN ISNULL(ORDERS.Userdefine01,'0') ELSE ISNULL(CLC1.Short,'0') END), CONVERT(DATETIME, ORDERS.Userdefine10))END)ELSE '' END  ,  
      
         CASE WHEN  bb.pick_qty=cc.pack_qty THEN CASE WHEN ISNULL(CLR5.Short,'N') = 'Y' THEN LTRIM(RTRIM(ISNULL(MAX(ORDERS.C_contact1),''))) + ' ' + LTRIM(RTRIM(ISNULL(MAX(ORDERS.C_Phone1),'')))       
                                                                                        ELSE CAST(ORDERS.Notes AS CHAR(255)) END       
                                            ELSE '' END AS Notes,       
         CASE WHEN  bb.pick_qty=cc.pack_qty THEN RTRIM(CAST(STORER.notes1 AS CHAR(255))) + SPACE(1) + RTRIM(CAST(STORER.notes2 AS CHAR(255))) ELSE '' END AS Remarks,          
         CASE WHEN  bb.pick_qty=cc.pack_qty THEN ORDERS.C_City  ELSE '' END ,       
         CASE WHEN  bb.pick_qty=cc.pack_qty THEN Orders.intermodalvehicle  ELSE '' END ,       
         CASE WHEN  bb.pick_qty=cc.pack_qty THEN CODELKUP.Short  ELSE '' END ,      
         ShowField = CASE WHEN  bb.pick_qty=cc.pack_qty THEN (CASE WHEN ISNULL(CLR.Code,'') <> '' THEN 'Y' ELSE 'N' END) ELSE '' END  ,      
         ShowCRD  = CASE WHEN  bb.pick_qty=cc.pack_qty THEN (CASE WHEN ((ISNULL(STORER.SUSR1,'') = 'CRD' AND ISNULL(ORDERS.userdefine10,'') <> ''      
                    AND (CONVERT(NVARCHAR(10),(CONVERT(DATETIME,ORDERS.userdefine10) +     
                    CONVERT(INT,CASE WHEN CLC1.Short IS NULL AND ORDERS.StorerKey = 'NIKECN' THEN 0 WHEN CLC1.Short IS NULL THEN ORDERS.Userdefine01 ELSE CLC1.Short END)),121))     
                    <  CONVERT(NVARCHAR(10),ORDERS.DeliveryDate,121))) THEN                
            'Y' ELSE 'N' END      
            ) ELSE '' END,            
         CASE WHEN  bb.pick_qty=cc.pack_qty THEN  CONVERT(NVARCHAR(10),ORDERS.DeliveryDate,121) ELSE '' END CRD,       
         LP = CASE WHEN  bb.pick_qty=cc.pack_qty THEN ( CASE WHEN @c_Zone = 'CRW'  THEN CASE WHEN ISNULL(CLR7.Notes,'') <> '' THEN CLR7.Notes ELSE CLR2.NOTES2   END       
                                                             WHEN @c_Zone = 'CRWP' THEN CASE WHEN ISNULL(CLR7.Notes,'') <> '' THEN CLR7.Notes ELSE CLR2.NOTES    END       
                                                             WHEN @c_Zone = 'ECTR' THEN CASE WHEN ISNULL(CLR7.Notes,'') <> '' THEN CLR7.Notes ELSE CLR2.NOTES2   END       
                                                             ELSE CASE WHEN ISNULL(CLR7.Notes,'') <> '' THEN CLR7.Notes ELSE '' END END ) ELSE '' END,       
         CT = CASE WHEN  bb.pick_qty=cc.pack_qty THEN ( CASE WHEN @c_Zone = 'CRW'  THEN CASE WHEN ISNULL(CLR8.Notes,'') <> '' THEN CLR8.Notes ELSE CLR1.NOTES2   END         
                                                             WHEN @c_Zone = 'CRWP' THEN CASE WHEN ISNULL(CLR8.Notes,'') <> '' THEN CLR8.Notes ELSE CLR1.NOTES    END       
                                                             WHEN @c_Zone = 'ECTR' THEN CASE WHEN ISNULL(CLR8.Notes,'') <> '' THEN CLR8.Notes ELSE CLR1.NOTES2   END       
                                                             ELSE CASE WHEN ISNULL(CLR8.Notes,'') <> '' THEN CLR8.Notes ELSE '' END END ) ELSE '' END,         
         TL = CASE WHEN  bb.pick_qty=cc.pack_qty THEN ( CASE WHEN @c_Zone = 'CRW'  THEN CASE WHEN ISNULL(CLR9.Notes,'') <> '' THEN CLR9.Notes ELSE CLR3.NOTES2   END       
                                                             WHEN @c_Zone = 'CRWP' THEN CASE WHEN ISNULL(CLR9.Notes,'') <> '' THEN CLR9.Notes ELSE CLR3.NOTES    END       
                                                             WHEN @c_Zone = 'ECTR' THEN CASE WHEN ISNULL(CLR9.Notes,'') <> '' THEN CLR9.Notes ELSE CLR3.NOTES2   END       
                                                             ELSE CASE WHEN ISNULL(CLR9.Notes,'') <> '' THEN CLR9.Notes ELSE '' END END ) ELSE '' END,              
         FX = CASE WHEN  bb.pick_qty=cc.pack_qty THEN ( CASE WHEN @c_Zone = 'CRW'  THEN CASE WHEN ISNULL(CLR10.Notes,'') <> '' THEN CLR10.Notes ELSE CLR4.NOTES2 END         
                                                             WHEN @c_Zone = 'CRWP' THEN CASE WHEN ISNULL(CLR10.Notes,'') <> '' THEN CLR10.Notes ELSE CLR4.NOTES  END       
                                                             WHEN @c_Zone = 'ECTR' THEN CASE WHEN ISNULL(CLR10.Notes,'') <> '' THEN CLR10.Notes ELSE CLR4.NOTES2 END       
                                                             ELSE CASE WHEN ISNULL(CLR10.Notes,'') <> '' THEN CLR10.Notes ELSE '' END END ) ELSE '' END,    
         [SITE] = @c_Zone,                                                   
         CASE WHEN ISNULL(CLR5.Short,'N') = 'Y' THEN (SELECT TOP 1 ISNULL(CL.Description,'')     
                                                      FROM CODELKUP CL (NOLOCK)     
                                                      WHERE CL.LISTNAME = 'RDATA' AND CL.Code = '001') ELSE '' END AS O2,    
         ISNULL(CLR5.Short,'N') AS ShowStorerCols,    
         ORDERS.ExternPOKey,    
         CASE WHEN ISNULL(CLR6.Short,'N') = 'Y' AND ISNUMERIC(CLC.Short) = 1 THEN CONVERT(NVARCHAR(30), DATEADD(d,CAST(CLC.Short AS INT),MBOL.AddDate), 121) ELSE NULL END AS NewETA,       
         @c_PrefixPsn AS PrefixPsn,         
         ORDERS.DeliveryDate           
      FROM  MBOL (NOLOCK)      
      JOIN MBOLDETAIL (NOLOCK) ON (MBOL.Mbolkey = MBOLDETAIL.Mbolkey )         
      INNER JOIN ORDERS (NOLOCK)ON (MBOLDETAIL.Orderkey = Orders.Orderkey)      
      INNER JOIN PACKHEADER (NOLOCK) ON (ORDERS.Storerkey = PACKHEADER.Storerkey AND ORDERS.Loadkey = PACKHEADER.Loadkey)      
      INNER JOIN PACKDETAIL (NOLOCK) ON (PACKHEADER.Storerkey = PACKDETAIL.Storerkey AND PACKHEADER.Pickslipno = PACKDETAIL.Pickslipno)       
      INNER JOIN PICKHEADER (NOLOCK) ON (PACKHEADER.Pickslipno = PICKHEADER.Pickheaderkey)      
      LEFT OUTER JOIN CODELKUP CLC (NOLOCK) ON (CLC.LONG = ORDERS.Facility AND       
                                                CLC.Description = ORDERS.c_City AND      
                                                CLC.ListName = @c_CodeCityLdTime AND         
                                                CAST(CLC.Notes AS CHAR(30)) = Orders.intermodalvehicle)         
      LEFT OUTER JOIN CODELKUP CLC1 (NOLOCK) ON (CLC1.LONG = ORDERS.Facility AND       
                                                 CLC1.[Description] = ORDERS.C_City AND      
                                                 CLC1.ListName = @c_CodeCityLdTime AND    
                                                 CLC1.Storerkey = ORDERS.StorerKey)        
      LEFT OUTER JOIN CODELKUP (NOLOCK) ON (CODELKUP.Listname = 'STRDOMAIN' AND      
                                            CODELKUP.Code = ORDERS.StorerKey)       
      LEFT OUTER JOIN STORER (NOLOCK) ON (STORER.StorerKey = ORDERS.ConsigneeKey)       
      LEFT OUTER JOIN Codelkup CLR (NOLOCK) ON (ORDERS.Storerkey = CLR.Storerkey AND CLR.Code = 'SHOWFIELD'                                              
                                            AND CLR.Listname = 'REPORTCFG' AND CLR.Long = 'r_dw_dmanifest_sum10' AND ISNULL(CLR.Short,'') <> 'N')      
      LEFT OUTER JOIN CODELKUP CLR1 (NOLOCK) ON (ORDERS.Storerkey = CLR1.Storerkey AND CLR1.Listname = 'REPORTCFG'        
                                            AND CLR1.Long = 'r_dw_dmanifest_sum10' AND CLR1.Code = 'ShowCTName' AND ISNULL(CLR1.Short,'') <> 'N')      
      LEFT OUTER JOIN CODELKUP CLR2 (NOLOCK) ON (ORDERS.Storerkey = CLR2.Storerkey AND CLR2.Listname = 'REPORTCFG'        
                                            AND CLR2.Long = 'r_dw_dmanifest_sum10' AND CLR2.Code = 'ShowLPName' AND ISNULL(CLR2.Short,'') <> 'N')      
      LEFT OUTER JOIN CODELKUP CLR3 (NOLOCK) ON (ORDERS.Storerkey = CLR3.Storerkey AND CLR3.Listname = 'REPORTCFG'        
                                            AND CLR3.Long = 'r_dw_dmanifest_sum10' AND CLR3.Code = 'ShowTLName' AND ISNULL(CLR3.Short,'') <> 'N')      
      LEFT OUTER JOIN CODELKUP CLR4 (NOLOCK) ON (ORDERS.Storerkey = CLR4.Storerkey AND CLR4.Listname = 'REPORTCFG'        
                                            AND CLR4.Long = 'r_dw_dmanifest_sum10' AND CLR4.Code = 'ShowFXName' AND ISNULL(CLR4.Short,'') <> 'N')             
      LEFT OUTER JOIN CODELKUP CLR5 (NOLOCK) ON (ORDERS.Storerkey = CLR5.Storerkey AND CLR5.Listname = 'REPORTCFG'        
                                             AND CLR5.Long = 'r_dw_dmanifest_sum10' AND CLR5.Code = 'ShowStorerCols' AND ISNULL(CLR5.Short,'') <> 'N')      
                                             AND CLR5.Code2 = ORDERS.Facility      
      LEFT OUTER JOIN CODELKUP CLR6 (NOLOCK) ON (ORDERS.Storerkey = CLR6.Storerkey AND CLR6.Listname = 'REPORTCFG'        
                                AND CLR6.Long = 'r_dw_dmanifest_sum10' AND CLR6.Code = 'ShowNewETA' AND ISNULL(CLR6.Short,'') <> 'N')      
                                             AND CLR6.Code2 = ORDERS.Facility       
      LEFT OUTER JOIN CODELKUP CLR7 (NOLOCK) ON (ORDERS.Storerkey = CLR7.Storerkey AND CLR7.Listname = 'NIKESITE'        
                                             AND CLR7.UDF01 = @c_Zone AND CLR7.Short IN ('LP')    
                                             AND CLR7.Code2 = ORDERS.Facility)      
      LEFT OUTER JOIN CODELKUP CLR8 (NOLOCK) ON (ORDERS.Storerkey = CLR8.Storerkey AND CLR8.Listname = 'NIKESITE'        
                                             AND CLR8.UDF01 = @c_Zone AND CLR8.Short IN ('CT')    
                                             AND CLR8.Code2 = ORDERS.Facility)      
      LEFT OUTER JOIN CODELKUP CLR9 (NOLOCK) ON (ORDERS.Storerkey = CLR9.Storerkey AND CLR9.Listname = 'NIKESITE'        
                                             AND CLR9.UDF01 = @c_Zone AND CLR9.Short IN ('TL')    
                                             AND CLR9.Code2 = ORDERS.Facility)      
      LEFT OUTER JOIN CODELKUP CLR10 (NOLOCK) ON (ORDERS.Storerkey = CLR10.Storerkey AND CLR10.Listname = 'NIKESITE'        
                                             AND CLR10.UDF01 = @c_Zone AND CLR10.Short IN ('FX')    
                                             AND CLR10.Code2 = ORDERS.Facility)       
      LEFT JOIN #tmp_byload TBL ON orders.LoadKey=TBL.loadkey              
      LEFT JOIN #tmp_PICKQTYBYLOAD bb ON    orders.LoadKey=bb.pick_load       
      LEFT JOIN #tmp_PACKQTYBYLOAD cc ON    orders.LoadKey=cc.pack_load                                                        
      WHERE ( MBOL.MbolKey = @c_mbolKey)      
      AND PACKDETAIL.RefNo = @c_Zone      
      AND PACKDETAIL.StorerKey = @c_storerkey             
      AND   ( RTRIM(PackHeader.OrderKey) IS NULL OR RTRIM(PackHeader.OrderKey) = '')       
      GROUP BY PackHeader.Storerkey, PackHeader.Pickslipno,      
               Packdetail.CartonNo,      
               MBOL.AddWho,         
               MBOL.MbolKey,         
               MBOL.BookingReference,         
               MBOL.OtherReference,         
               MBOL.PlaceOfLoading,         
               MBOL.PlaceOfDischarge,         
               MBOL.EffectiveDate,         
               MBOL.CarrierKey,         
               MBOL.Vessel,         
               MBOL.VoyageNumber,         
               MBOL.DRIVERName,         
               MBOL.Editdate,        
               ORDERS.Loadkey,      
               MBOL.Facility,      
               Pickheader.Zone,      
               MBOL.EditDate,      
               CLC.Short,      
               CAST(ORDERS.Notes AS CHAR(255)),        
               RTRIM(CAST(STORER.notes1 AS CHAR(255))) + SPACE(1) + RTRIM(CAST(STORER.notes2 AS CHAR(255))),      
               ORDERS.C_City,      
               Orders.intermodalvehicle,       
               CODELKUP.Short,      
               ORDERS.Userdefine01,      
               ORDERS.Userdefine04,      
               ORDERS.ExternPOKey,      
               ISNULL(CLR.Code,''),      
               ISNULL(STORER.SUSR1,'') ,      
               CASE WHEN  bb.pick_qty=cc.pack_qty THEN  CONVERT(NVARCHAR(10),ORDERS.DeliveryDate,121) ELSE '' END,      
               CASE WHEN  bb.pick_qty=cc.pack_qty THEN ( CASE WHEN @c_Zone = 'CRW'  THEN CASE WHEN ISNULL(CLR7.Notes,'') <> '' THEN CLR7.Notes ELSE CLR2.NOTES2   END       
                                                              WHEN @c_Zone = 'CRWP' THEN CASE WHEN ISNULL(CLR7.Notes,'') <> '' THEN CLR7.Notes ELSE CLR2.NOTES    END       
                                                              WHEN @c_Zone = 'ECTR' THEN CASE WHEN ISNULL(CLR7.Notes,'') <> '' THEN CLR7.Notes ELSE CLR2.NOTES2   END       
               ELSE CASE WHEN ISNULL(CLR7.Notes,'') <> '' THEN CLR7.Notes ELSE '' END END ) ELSE '' END,    
               CASE WHEN  bb.pick_qty=cc.pack_qty THEN ( CASE WHEN @c_Zone = 'CRW'  THEN CASE WHEN ISNULL(CLR8.Notes,'') <> '' THEN CLR8.Notes ELSE CLR1.NOTES2   END       
                                                              WHEN @c_Zone = 'CRWP' THEN CASE WHEN ISNULL(CLR8.Notes,'') <> '' THEN CLR8.Notes ELSE CLR1.NOTES    END       
                                                              WHEN @c_Zone = 'ECTR' THEN CASE WHEN ISNULL(CLR8.Notes,'') <> '' THEN CLR8.Notes ELSE CLR1.NOTES2   END       
                                                              ELSE CASE WHEN ISNULL(CLR8.Notes,'') <> '' THEN CLR8.Notes ELSE '' END END ) ELSE '' END,       
               CASE WHEN  bb.pick_qty=cc.pack_qty THEN ( CASE WHEN @c_Zone = 'CRW'  THEN CASE WHEN ISNULL(CLR9.Notes,'') <> '' THEN CLR9.Notes ELSE CLR3.NOTES2   END       
                                                              WHEN @c_Zone = 'CRWP' THEN CASE WHEN ISNULL(CLR9.Notes,'') <> '' THEN CLR9.Notes ELSE CLR3.NOTES    END       
                  WHEN @c_Zone = 'ECTR' THEN CASE WHEN ISNULL(CLR9.Notes,'') <> '' THEN CLR9.Notes ELSE CLR3.NOTES2   END       
                                                              ELSE CASE WHEN ISNULL(CLR9.Notes,'') <> '' THEN CLR9.Notes ELSE '' END END ) ELSE '' END,              
               CASE WHEN  bb.pick_qty=cc.pack_qty THEN ( CASE WHEN @c_Zone = 'CRW'  THEN CASE WHEN ISNULL(CLR10.Notes,'') <> '' THEN CLR10.Notes ELSE CLR4.NOTES2 END       
                                                              WHEN @c_Zone = 'CRWP' THEN CASE WHEN ISNULL(CLR10.Notes,'') <> '' THEN CLR10.Notes ELSE CLR4.NOTES  END       
                                                              WHEN @c_Zone = 'ECTR' THEN CASE WHEN ISNULL(CLR10.Notes,'') <> '' THEN CLR10.Notes ELSE CLR4.NOTES2 END       
                                                              ELSE CASE WHEN ISNULL(CLR10.Notes,'') <> '' THEN CLR10.Notes ELSE '' END END ) ELSE '' END,    
               ORDERS.userdefine10       
               ,CASE WHEN TBL.cntRefno>1 THEN  @c_Zone + '-' + ORDERS.Loadkey ELSE ORDERS.Loadkey END     
               ,bb.pick_qty,cc.pack_qty,       
               ISNULL(CLR5.Short,'N'),    
               ORDERS.ExternPOKey,    
               CASE WHEN ISNULL(CLR6.Short,'N') = 'Y' AND ISNUMERIC(CLC.Short) = 1 THEN CONVERT(NVARCHAR(30), DATEADD(d,CAST(CLC.Short AS INT),MBOL.AddDate), 121) ELSE NULL END,             
               CLC1.Short,           
               ORDERS.StorerKey,     
               ORDERS.DeliveryDate,
					ORDERS.Type,			--ML01
					ORDERS.C_Company,		--ML01
					ORDERS.M_Company	   --ML01
   END      
   ELSE      
   BEGIN --zone=''     
      SELECT DISTINCT MBOL.AddWho,         
         MBOL.MbolKey,         
         MBOL.BookingReference,         
         MBOL.OtherReference,         
         MBOL.PlaceOfLoading,         
         MBOL.PlaceOfDischarge,         
         MBOL.EffectiveDate,         
         MBOL.CarrierKey,         
         MBOL.Vessel,         
         MBOL.VoyageNumber,         
         MBOL.DRIVERName,         
         MBOL.Editdate,        
         ORDERS.ConsigneeKey,         
         ORDERS.ExternOrderKey,        
         ORDERS.C_Address1,      
         ORDERS.C_Address2,      
         ORDERS.C_Address3,      
         ORDERS.C_Address4,      
         ORDERS.C_Contact1,      
         ORDERS.C_Contact2,      
         ORDERS.C_Phone1,      
         ORDERS.C_Phone2,      
         ORDERS.C_Fax1,      
         ORDERS.C_Fax2,      
         ORDERS.Loadkey,    
         ORDERS.DeliveryDate,      
         ORDERS.Grossweight,      
         ORDERS.Capacity,       
         ORDERS.Loadkey AS OHLOAD,      
         MBOL.Facility,      
         1 AS CartonNo,      
         '' AS Pickslipno,      
         '' AS pickzone,      
         '0' AS FWQTY,      
         '0' AS APPQTY,      
         '0' AS EQQTY,      
         --Orders.C_Company, 
			CASE WHEN  ORDERS.type IN ('ZS05','ZS06') THEN Orders.M_Company ELSE Orders.C_Company END,	--ML01
         ETA = CASE WHEN ISNULL(STORER.SUSR1,'') = 'CRD' THEN     
         (    
               CASE WHEN (CLC1.Short IS NULL) AND ORDERS.StorerKey = 'NIKECN' THEN MBOL.EditDate   
                    WHEN ISDATE(ORDERS.Userdefine10) = 1 AND (ISNUMERIC(ISNULL(ORDERS.Userdefine01,'0')) = 1 OR ISNUMERIC(ISNULL(CLC1.Short,'0')) = 1) AND ISDATE(ORDERS.DeliveryDate) = 0        
                    THEN DATEADD(DAY, CONVERT(INT, CASE WHEN CLC1.Short IS NULL THEN ISNULL(ORDERS.Userdefine01,'0') ELSE ISNULL(CLC1.Short,'0') END), CONVERT(DATETIME, ORDERS.Userdefine10))     
                    WHEN ISDATE(ORDERS.Userdefine10) = 1 AND (ISNUMERIC(ISNULL(ORDERS.Userdefine01,'0')) = 1 OR ISNUMERIC(ISNULL(CLC1.Short,'0')) = 1) AND ISDATE(ORDERS.DeliveryDate) = 1      
                    THEN CASE WHEN DATEADD(DAY, CONVERT(INT, CASE WHEN CLC1.Short IS NULL THEN ISNULL(ORDERS.Userdefine01,'0') ELSE ISNULL(CLC1.Short,'0') END), CONVERT(DATETIME, ORDERS.Userdefine10))        
                                   >= CONVERT(DATETIME, ORDERS.DeliveryDate)      
                           THEN DATEADD(DAY, CONVERT(INT, CASE WHEN CLC1.Short IS NULL THEN ISNULL(ORDERS.Userdefine01,'0') ELSE ISNULL(CLC1.Short,'0') END), CONVERT(DATETIME, ORDERS.Userdefine10))        
                              ELSE CONVERT(DATETIME, ORDERS.DeliveryDate)    
                              END        
                    WHEN (CLC.Short IS NULL OR ISNUMERIC(CLC.Short) <> 1) AND ORDERS.StorerKey <> 'NIKECN' THEN MBOL.EditDate          
                    ELSE CASE WHEN Orders.Intermodalvehicle = 'ILOE'     
                         THEN DATEADD(HOUR, CEILING(CAST(CLC.Short AS REAL)), CONVERT(DATETIME,CONVERT(CHAR(8),MBOL.EditDate,112))+1)      
                         ELSE CASE WHEN ORDERS.Storerkey = 'NIKECN' THEN DATEADD(DAY, CEILING(CAST(CLC1.Short AS REAL)), MBOL.EditDate )          
                                                                    ELSE DATEADD(DAY, CEILING(CAST(CLC.Short AS REAL)), MBOL.EditDate ) END      
                    END    
              
               END       
         )    
         ELSE DATEADD(DAY, CONVERT(INT, CASE WHEN CLC1.Short IS NULL THEN ISNULL(ORDERS.Userdefine01,'0') ELSE ISNULL(CLC1.Short,'0') END), CONVERT(DATETIME, ORDERS.Userdefine10))END,      
         CASE WHEN ISNULL(CLR5.Short,'N') = 'Y' THEN LTRIM(RTRIM(ISNULL(ORDERS.C_contact1,''))) + ' ' + LTRIM(RTRIM(ISNULL(ORDERS.C_Phone1,'')))      
                                                ELSE CAST(ORDERS.Notes as Char(255)) END as Notes,          
         ISNULL(RTRIM(CAST(STORER.notes1 as Char(255))), '') + SPACE(1) + ISNULL(RTRIM(CAST(STORER.notes2 as Char(255))),'') as Remarks,             
         ORDERS.C_City,      
         Orders.intermodalvehicle,       
         CODELKUP.Short AS Domain,      
         ShowField = CASE WHEN ISNULL(CLR.Code,'') <> '' THEN 'Y' ELSE 'N' END ,      
         ShowCRD  = CASE WHEN ((ISNULL(STORER.SUSR1,'') = 'CRD' AND ISNULL(ORDERS.userdefine10,'') <> ''      
                              AND (CONVERT(NVARCHAR(10),(CONVERT(DATETIME,ORDERS.userdefine10) +     
                    CONVERT(INT,CASE WHEN CLC1.Short IS NULL AND ORDERS.StorerKey = 'NIKECN' THEN 0 WHEN CLC1.Short IS NULL THEN ORDERS.Userdefine01 ELSE CLC1.Short END)),121))  
                    <  CONVERT(NVARCHAR(10),ORDERS.DeliveryDate,121))) THEN              
            'Y' ELSE 'N' END,     
         CRD = CONVERT(NVARCHAR(10),ORDERS.DeliveryDate,121),                   
         LP = CASE WHEN ISNULL(ORDERS.Userdefine02,'')='' THEN CLR2.NOTES2 ELSE CLR2.NOTES END,      
         CT = CASE WHEN ISNULL(ORDERS.Userdefine02,'')='' THEN CLR1.NOTES2 ELSE CLR1.NOTES END,      
         TL = CASE WHEN ISNULL(ORDERS.Userdefine02,'')='' THEN CLR3.NOTES2 ELSE CLR3.NOTES END,      
         FX = CASE WHEN ISNULL(ORDERS.Userdefine02,'')='' THEN CLR4.NOTES2 ELSE CLR4.NOTES END,      
         [SITE] = '',                 
         CASE WHEN ISNULL(CLR5.Short,'N') = 'Y' THEN (SELECT TOP 1 ISNULL(CL.Description,'')     
                                                      FROM CODELKUP CL (NOLOCK)     
                                                      WHERE CL.LISTNAME = 'RDATA' AND CL.Code = '001') ELSE '' END AS O2,    
         ISNULL(CLR5.Short,'N') AS ShowStorerCols,    
         ORDERS.ExternPOKey,    
         CASE WHEN ISNULL(CLR6.Short,'N') = 'Y' AND ISNUMERIC(CLC.Short) = 1 THEN CONVERT(NVARCHAR(30), DATEADD(d,CAST(CLC.Short AS INT),MBOL.AddDate), 121) ELSE NULL END AS NewETA    
         ,@c_PrefixPsn AS PrefixPsn
      FROM  MBOL (NOLOCK)      
      JOIN MBOLDETAIL (NOLOCK) ON (MBOL.Mbolkey = MBOLDETAIL.Mbolkey )         
      JOIN ORDERS (NOLOCK)ON (MBOLDETAIL.Orderkey = Orders.Orderkey)      
      LEFT OUTER JOIN PICKHEADER (NOLOCK) ON (ORDERS.Loadkey = PICKHEADER.ExternOrderkey)      
      LEFT OUTER JOIN CODELKUP CLC (NOLOCK) ON (CLC.LONG = ORDERS.Facility AND       
                                                CLC.Description = ORDERS.c_City AND      
                                                CLC.ListName = @c_CodeCityLdTime AND       
                                                CAST(CLC.Notes AS char(30)) = Orders.intermodalvehicle)         
      LEFT OUTER JOIN CODELKUP CLC1 (NOLOCK) ON (CLC1.LONG = ORDERS.Facility AND       
                                                 CLC1.[Description] = ORDERS.C_City AND      
                                                 CLC1.ListName = @c_CodeCityLdTime AND    
                                                 CLC1.Storerkey = ORDERS.StorerKey)     
      LEFT OUTER JOIN CODELKUP (NOLOCK) ON (CODELKUP.Listname = 'STRDOMAIN' AND      
                                            CODELKUP.Code = ORDERS.StorerKey)       
      LEFT OUTER JOIN STORER (NOLOCK) ON (STORER.StorerKey = ORDERS.ConsigneeKey)      
      LEFT OUTER JOIN Codelkup CLR (NOLOCK) ON (ORDERS.Storerkey = CLR.Storerkey AND CLR.Code = 'SHOWFIELD'                                              
                                            AND CLR.Listname = 'REPORTCFG' AND CLR.Long = 'r_dw_dmanifest_sum10' AND ISNULL(CLR.Short,'') <> 'N')      
      LEFT OUTER JOIN CODELKUP CLR1 (NOLOCK) ON (ORDERS.Storerkey = CLR1.Storerkey AND CLR1.Listname = 'REPORTCFG'        
                                             AND CLR1.Long = 'r_dw_dmanifest_sum10' AND CLR1.Code = 'ShowCTName' AND ISNULL(CLR1.Short,'') <> 'N')      
      LEFT OUTER JOIN CODELKUP CLR2 (NOLOCK) ON (ORDERS.Storerkey = CLR2.Storerkey AND CLR2.Listname = 'REPORTCFG'        
                                             AND CLR2.Long = 'r_dw_dmanifest_sum10' AND CLR2.Code = 'ShowLPName' AND ISNULL(CLR2.Short,'') <> 'N')      
      LEFT OUTER JOIN CODELKUP CLR3 (NOLOCK) ON (ORDERS.Storerkey = CLR3.Storerkey AND CLR3.Listname = 'REPORTCFG'        
                                             AND CLR3.Long = 'r_dw_dmanifest_sum10' AND CLR3.Code = 'ShowTLName' AND ISNULL(CLR3.Short,'') <> 'N')      
      LEFT OUTER JOIN CODELKUP CLR4 (NOLOCK) ON (ORDERS.Storerkey = CLR4.Storerkey AND CLR4.Listname = 'REPORTCFG'        
                                             AND CLR4.Long = 'r_dw_dmanifest_sum10' AND CLR4.Code = 'ShowFXName' AND ISNULL(CLR4.Short,'') <> 'N')                                                  
      LEFT OUTER JOIN CODELKUP CLR5 (NOLOCK) ON (ORDERS.Storerkey = CLR5.Storerkey AND CLR5.Listname = 'REPORTCFG'        
                                             AND CLR5.Long = 'r_dw_dmanifest_sum10' AND CLR5.Code = 'ShowStorerCols' AND ISNULL(CLR5.Short,'') <> 'N')       
                                             AND CLR5.Code2 = ORDERS.Facility     
      LEFT OUTER JOIN CODELKUP CLR6 (NOLOCK) ON (ORDERS.Storerkey = CLR6.Storerkey AND CLR6.Listname = 'REPORTCFG'        
                                             AND CLR6.Long = 'r_dw_dmanifest_sum10' AND CLR6.Code = 'ShowNewETA' AND ISNULL(CLR6.Short,'') <> 'N')      
                                             AND CLR6.Code2 = ORDERS.Facility        
      WHERE ( MBOL.MbolKey = @c_mbolKey)      
      AND   PICKHEADER.Pickheaderkey IS NULL      
      UNION ALL      
      /*    Pack by Single Order */      
      SELECT DISTINCT MBOL.AddWho,         
         MBOL.MbolKey,         
         MBOL.BookingReference,         
         MBOL.OtherReference,         
         MBOL.PlaceOfLoading,         
         MBOL.PlaceOfDischarge,         
         MBOL.EffectiveDate,         
         MBOL.CarrierKey,         
         MBOL.Vessel,         
         MBOL.VoyageNumber,         
         MBOL.DRIVERName,         
         MBOL.Editdate,        
         ORDERS.ConsigneeKey,         
         ORDERS.ExternOrderKey,        
         ORDERS.C_Address1,      
         ORDERS.C_Address2,      
         ORDERS.C_Address3,      
         ORDERS.C_Address4,      
         ORDERS.C_Contact1,      
         ORDERS.C_Contact2,      
         ORDERS.C_Phone1,      
         ORDERS.C_Phone2,      
         ORDERS.C_Fax1,      
         ORDERS.C_Fax2,      
         ORDERS.Loadkey,     
         ORDERS.DeliveryDate,      
         ORDERS.Grossweight,      
         ORDERS.Capacity,       
         ORDERS.Loadkey AS OHLOAD,      
         MBOL.Facility,      
         Packdetail.CartonNo as CartonNo,      
         Packdetail.Pickslipno ,      
         Pickheader.Zone as PickZone,      
         (select sum(packdetail.qty)       
          from packdetail(nolock),sku(nolock) where packdetail.Storerkey = sku.Storerkey  AND packdetail.sku = sku.sku and sku.skugroup = 'FOOTWEAR'      
          and packdetail.Storerkey =PackHeader.Storerkey and packdetail.Pickslipno =PackHeader.Pickslipno ) AS FWQTY,      
         (select sum(packdetail.qty)      
          from packdetail(nolock),sku(nolock) where packdetail.Storerkey = sku.Storerkey  AND packdetail.sku = sku.sku and sku.skugroup = 'APPAREL'      
          and packdetail.Storerkey =PackHeader.Storerkey and packdetail.Pickslipno =PackHeader.Pickslipno ) AS APPQTY,      
         (select sum(packdetail.qty)       
          from packdetail(nolock),sku(nolock) where packdetail.Storerkey = sku.Storerkey  AND packdetail.sku = sku.sku and sku.skugroup = 'EQUIPMENT'      
          and packdetail.Storerkey =PackHeader.Storerkey and packdetail.Pickslipno =PackHeader.Pickslipno ) AS EQQTY,      
         --Orders.C_company,      
			CASE WHEN  ORDERS.type in ('ZS05','ZS06') THEN Orders.M_Company ELSE Orders.C_Company END,	--ML01
         ETA = CASE WHEN ISNULL(STORER.SUSR1,'') = 'CRD' THEN     
         (    
               CASE WHEN (CLC1.Short IS NULL) AND ORDERS.StorerKey = 'NIKECN' THEN MBOL.EditDate      
                    WHEN ISDATE(ORDERS.Userdefine10) = 1 AND (ISNUMERIC(ISNULL(ORDERS.Userdefine01,'0')) = 1 OR ISNUMERIC(ISNULL(CLC1.Short,'0')) = 1) AND ISDATE(ORDERS.DeliveryDate) = 0        
                    THEN DATEADD(DAY, CONVERT(INT, CASE WHEN CLC1.Short IS NULL THEN ISNULL(ORDERS.Userdefine01,'0') ELSE ISNULL(CLC1.Short,'0') END), CONVERT(DATETIME, ORDERS.Userdefine10))          
                    WHEN ISDATE(ORDERS.Userdefine10) = 1 AND (ISNUMERIC(ISNULL(ORDERS.Userdefine01,'0')) = 1 OR ISNUMERIC(ISNULL(CLC1.Short,'0')) = 1) AND ISDATE(ORDERS.DeliveryDate) = 1      
                    THEN CASE WHEN DATEADD(DAY, CONVERT(INT, CASE WHEN CLC1.Short IS NULL THEN ISNULL(ORDERS.Userdefine01,'0') ELSE ISNULL(CLC1.Short,'0') END), CONVERT(DATETIME, ORDERS.Userdefine10))          
                          >= CONVERT(DATETIME, ORDERS.DeliveryDate)      
                         THEN DATEADD(DAY, CONVERT(INT, CASE WHEN CLC1.Short IS NULL THEN ISNULL(ORDERS.Userdefine01,'0') ELSE ISNULL(CLC1.Short,'0') END), CONVERT(DATETIME, ORDERS.Userdefine10))        
                         ELSE CONVERT(DATETIME, ORDERS.DeliveryDate)     
                         END        
                    WHEN (CLC.Short IS NULL OR ISNUMERIC(CLC.Short) <> 1) AND ORDERS.StorerKey <> 'NIKECN' THEN MBOL.EditDate         
                    ELSE CASE WHEN Orders.Intermodalvehicle = 'ILOE'     
                              THEN DATEADD(hour, Ceiling(Cast(CLC.Short as real)), CONVERT(datetime,convert(char(8),MBOL.EditDate,112))+1)      
                              ELSE CASE WHEN ORDERS.Storerkey = 'NIKECN' THEN DATEADD(DAY, CEILING(CAST(CLC1.Short AS REAL)), MBOL.EditDate )        
                                                                         ELSE DATEADD(DAY, CEILING(CAST(CLC.Short AS REAL)), MBOL.EditDate ) END      
                         END      
               END    
         )    
         ELSE DATEADD(DAY, CONVERT(INT, CASE WHEN CLC1.Short IS NULL THEN ISNULL(ORDERS.Userdefine01,'0') ELSE ISNULL(CLC1.Short,'0') END), CONVERT(DATETIME, ORDERS.Userdefine10))END,         
         CASE WHEN ISNULL(CLR5.Short,'N') = 'Y' THEN LTRIM(RTRIM(ISNULL(ORDERS.C_contact1,''))) + ' ' + LTRIM(RTRIM(ISNULL(ORDERS.C_Phone1,'')))      
                                                ELSE CAST(ORDERS.Notes as Char(255)) END as Notes,            
         RTRIM(CAST(STORER.notes1 as Char(255))) + SPACE(1) + RTRIM(CAST(STORER.notes2 as Char(255))) as Remarks,             
         ORDERS.C_City,       
         Orders.intermodalvehicle,       
         CODELKUP.Short,      
         ShowField = CASE WHEN ISNULL(CLR.Code,'') <> '' THEN 'Y' ELSE 'N' END ,      
         ShowCRD  = CASE WHEN ((ISNULL(STORER.SUSR1,'') = 'CRD' AND ISNULL(ORDERS.userdefine10,'') <> ''      
                              AND (CONVERT(NVARCHAR(10),(CONVERT(DATETIME,ORDERS.userdefine10) +     
                    CONVERT(INT,CASE WHEN CLC1.Short IS NULL AND ORDERS.StorerKey = 'NIKECN' THEN 0 WHEN CLC1.Short IS NULL THEN ORDERS.Userdefine01 ELSE CLC1.Short END)),121)) 
                    <  CONVERT(NVARCHAR(10),ORDERS.DeliveryDate,121))) THEN              
            'Y' ELSE 'N' END,        
         CRD = CONVERT(NVARCHAR(10),ORDERS.DeliveryDate,121),                 
         LP = CASE WHEN ISNULL(ORDERS.Userdefine02,'')='' THEN CLR2.NOTES2 ELSE CLR2.NOTES END,      
         CT = CASE WHEN ISNULL(ORDERS.Userdefine02,'')='' THEN CLR1.NOTES2 ELSE CLR1.NOTES END,      
         TL = CASE WHEN ISNULL(ORDERS.Userdefine02,'')='' THEN CLR3.NOTES2 ELSE CLR3.NOTES END,      
         FX = CASE WHEN ISNULL(ORDERS.Userdefine02,'')='' THEN CLR4.NOTES2 ELSE CLR4.NOTES END,      
         [SITE] = '',               
         CASE WHEN ISNULL(CLR5.Short,'N') = 'Y' THEN (SELECT TOP 1 ISNULL(CL.Description,'')     
                                                      FROM CODELKUP CL (NOLOCK)     
                                                      WHERE CL.LISTNAME = 'RDATA' AND CL.Code = '001') ELSE '' END AS O2,    
         ISNULL(CLR5.Short,'N') AS ShowStorerCols,    
         ORDERS.ExternPOKey,    
         CASE WHEN ISNULL(CLR6.Short,'N') = 'Y' AND ISNUMERIC(CLC.Short) = 1 THEN CONVERT(NVARCHAR(30), DATEADD(d,CAST(CLC.Short AS INT),MBOL.AddDate), 121) ELSE NULL END AS NewETA        
         ,@c_PrefixPsn AS PrefixPsn     
      FROM  MBOL (NOLOCK)      
      JOIN MBOLDETAIL (NOLOCK) ON (MBOL.Mbolkey = MBOLDETAIL.Mbolkey )         
      INNER JOIN ORDERS (NOLOCK)ON (MBOLDETAIL.Orderkey = Orders.Orderkey)      
      INNER JOIN PACKHEADER (NOLOCK) ON (ORDERS.Storerkey = PACKHEADER.Storerkey AND ORDERS.Orderkey = PACKHEADER.Orderkey)      
      INNER JOIN PACKDETAIL (NOLOCK) ON (PACKHEADER.Storerkey = PACKDETAIL.Storerkey AND PACKHEADER.Pickslipno = PACKDETAIL.Pickslipno)       
      INNER JOIN PICKHEADER (NOLOCK) ON (PACKHEADER.Pickslipno = PICKHEADER.Pickheaderkey)      
      LEFT OUTER JOIN CODELKUP CLC (NOLOCK) ON (CLC.LONG = ORDERS.Facility AND       
                                                CLC.Description = ORDERS.c_City AND      
                                                CLC.ListName = @c_CodeCityLdTime AND        
                                                CAST(CLC.Notes AS char(30)) = Orders.intermodalvehicle)         
      LEFT OUTER JOIN CODELKUP CLC1 (NOLOCK) ON (CLC1.LONG = ORDERS.Facility AND       
                                                 CLC1.[Description] = ORDERS.C_City AND      
                                                 CLC1.ListName = @c_CodeCityLdTime AND    
                                                 CLC1.Storerkey = ORDERS.StorerKey)        
      LEFT OUTER JOIN CODELKUP (NOLOCK) ON (CODELKUP.Listname = 'STRDOMAIN' AND      
                                            CODELKUP.Code = ORDERS.StorerKey)       
      LEFT OUTER JOIN STORER (NOLOCK) ON (STORER.StorerKey = ORDERS.ConsigneeKey)      
      LEFT OUTER JOIN Codelkup CLR (NOLOCK) ON (ORDERS.Storerkey = CLR.Storerkey AND CLR.Code = 'SHOWFIELD'                                              
                                            AND CLR.Listname = 'REPORTCFG' AND CLR.Long = 'r_dw_dmanifest_sum10' AND ISNULL(CLR.Short,'') <> 'N')      
      LEFT OUTER JOIN CODELKUP CLR1 (NOLOCK) ON (ORDERS.Storerkey = CLR1.Storerkey AND CLR1.Listname = 'REPORTCFG'        
                                             AND CLR1.Long = 'r_dw_dmanifest_sum10' AND CLR1.Code = 'ShowCTName' AND ISNULL(CLR1.Short,'') <> 'N')      
      LEFT OUTER JOIN CODELKUP CLR2 (NOLOCK) ON (ORDERS.Storerkey = CLR2.Storerkey AND CLR2.Listname = 'REPORTCFG'        
                                             AND CLR2.Long = 'r_dw_dmanifest_sum10' AND CLR2.Code = 'ShowLPName' AND ISNULL(CLR2.Short,'') <> 'N')      
      LEFT OUTER JOIN CODELKUP CLR3 (NOLOCK) ON (ORDERS.Storerkey = CLR3.Storerkey AND CLR3.Listname = 'REPORTCFG'        
                                             AND CLR3.Long = 'r_dw_dmanifest_sum10' AND CLR3.Code = 'ShowTLName' AND ISNULL(CLR3.Short,'') <> 'N')      
      LEFT OUTER JOIN CODELKUP CLR4 (NOLOCK) ON (ORDERS.Storerkey = CLR4.Storerkey AND CLR4.Listname = 'REPORTCFG'        
                                             AND CLR4.Long = 'r_dw_dmanifest_sum10' AND CLR4.Code = 'ShowFXName' AND ISNULL(CLR4.Short,'') <> 'N')                                                 
      LEFT OUTER JOIN CODELKUP CLR5 (NOLOCK) ON (ORDERS.Storerkey = CLR5.Storerkey AND CLR5.Listname = 'REPORTCFG'        
                                             AND CLR5.Long = 'r_dw_dmanifest_sum10' AND CLR5.Code = 'ShowStorerCols' AND ISNULL(CLR5.Short,'') <> 'N')     
                                             AND CLR5.Code2 = ORDERS.Facility       
      LEFT OUTER JOIN CODELKUP CLR6 (NOLOCK) ON (ORDERS.Storerkey = CLR6.Storerkey AND CLR6.Listname = 'REPORTCFG'        
                                             AND CLR6.Long = 'r_dw_dmanifest_sum10' AND CLR6.Code = 'ShowNewETA' AND ISNULL(CLR6.Short,'') <> 'N')      
                                             AND CLR6.Code2 = ORDERS.Facility      
      WHERE ( MBOL.MbolKey = @c_mbolKey)      
      AND   ( RTRIM(PICKHEADER.OrderKey) IS NOT NULL AND RTRIM(PICKHEADER.OrderKey) <> '')       
      UNION ALL      
      /*    Pack by Same ShipTo Orders */      
      SELECT MBOL.AddWho,         
         MBOL.MbolKey,         
         MBOL.BookingReference,         
         MBOL.OtherReference,         
         MBOL.PlaceOfLoading,         
         MBOL.PlaceOfDischarge,         
         MBOL.EffectiveDate,         
         MBOL.CarrierKey,         
         MBOL.Vessel,         
         MBOL.VoyageNumber,         
         MBOL.DRIVERName,         
         MBOL.Editdate,        
         MAX(ORDERS.ConsigneeKey),         
         '' AS ExternOrderKey,        
         MAX(ORDERS.C_Address1),      
         MAX(ORDERS.C_Address2),      
         MAX(ORDERS.C_Address3),      
         MAX(ORDERS.C_Address4),      
         MAX(ORDERS.C_Contact1),      
         MAX(ORDERS.C_Contact2),      
         MAX(ORDERS.C_Phone1),      
         MAX(ORDERS.C_Phone2),      
         MAX(ORDERS.C_Fax1),      
         MAX(ORDERS.C_Fax2),      
         ORDERS.Loadkey,    
         MAX(ORDERS.DeliveryDate),      
         SUM(ORDERS.Grossweight),      
         SUM(ORDERS.Capacity),       
         ORDERS.Loadkey AS OHLOAD,      
         MBOL.Facility,      
         Packdetail.CartonNo,      
         PackHeader.Pickslipno,      
         Pickheader.Zone ,       
         (select sum(packdetail.qty)       
          from packdetail(nolock),sku(nolock) where packdetail.Storerkey = sku.Storerkey  AND packdetail.sku = sku.sku and sku.skugroup = 'FOOTWEAR'      
          and packdetail.Storerkey =PackHeader.Storerkey and packdetail.Pickslipno =PackHeader.Pickslipno ) AS FWQTY,      
         (select sum(packdetail.qty)      
          from packdetail(nolock),sku(nolock) where packdetail.Storerkey = sku.Storerkey  AND packdetail.sku = sku.sku and sku.skugroup = 'APPAREL'      
          and packdetail.Storerkey =PackHeader.Storerkey and packdetail.Pickslipno =PackHeader.Pickslipno ) AS APPQTY,      
         (select sum(packdetail.qty)       
          from packdetail(nolock),sku(nolock) where packdetail.Storerkey = sku.Storerkey  AND packdetail.sku = sku.sku and sku.skugroup = 'EQUIPMENT'      
          and packdetail.Storerkey =PackHeader.Storerkey and packdetail.Pickslipno =PackHeader.Pickslipno ) AS EQQTY,      
         --MAX(Orders.C_company),   
			CASE WHEN  ORDERS.type in ('ZS05','ZS06') THEN MAX(Orders.M_company) ELSE MAX(Orders.C_company) END,	--ML01
         ETA = CASE WHEN ISNULL(STORER.SUSR1,'') = 'CRD' THEN       
         (    
               CASE WHEN (CLC1.Short IS NULL) AND ORDERS.StorerKey = 'NIKECN' THEN MBOL.EditDate      
                    WHEN ISDATE(ORDERS.Userdefine10) = 1 AND (ISNUMERIC(ISNULL(ORDERS.Userdefine01,'0')) = 1 OR ISNUMERIC(ISNULL(CLC1.Short,'0')) = 1) AND ISDATE(ORDERS.DeliveryDate) = 0      
                    THEN DATEADD(DAY, CONVERT(INT, CASE WHEN CLC1.Short IS NULL THEN ISNULL(ORDERS.Userdefine01,'0') ELSE ISNULL(CLC1.Short,'0') END), CONVERT(DATETIME, ORDERS.Userdefine10))           
                    WHEN ISDATE(ORDERS.Userdefine10) = 1 AND (ISNUMERIC(ISNULL(ORDERS.Userdefine01,'0')) = 1 OR ISNUMERIC(ISNULL(CLC1.Short,'0')) = 1) AND ISDATE(ORDERS.DeliveryDate) = 1       
                    THEN CASE WHEN DATEADD(DAY, CONVERT(INT, CASE WHEN CLC1.Short IS NULL THEN ISNULL(ORDERS.Userdefine01,'0') ELSE ISNULL(CLC1.Short,'0') END), CONVERT(DATETIME, ORDERS.Userdefine10))      
                                   >= CONVERT(DATETIME, ORDERS.DeliveryDate)     
                              THEN DATEADD(DAY, CONVERT(INT, CASE WHEN CLC1.Short IS NULL THEN ISNULL(ORDERS.Userdefine01,'0') ELSE ISNULL(CLC1.Short,'0') END), CONVERT(DATETIME, ORDERS.Userdefine10))       
                              ELSE CONVERT(DATETIME, ORDERS.DeliveryDate)      
                              END        
                    WHEN (CLC.Short IS NULL OR ISNUMERIC(CLC.Short) <> 1) AND ORDERS.StorerKey <> 'NIKECN' THEN MBOL.EditDate          
                    ELSE CASE WHEN Orders.Intermodalvehicle = 'ILOE'     
                              THEN DateAdd(hour, Ceiling(Cast(CLC.Short as real)), CONVERT(datetime,convert(char(8),MBOL.EditDate,112))+1)      
                              ELSE CASE WHEN ORDERS.Storerkey = 'NIKECN' THEN DATEADD(DAY, CEILING(CAST(CLC1.Short AS REAL)), MBOL.EditDate )          
                                                                         ELSE DATEADD(DAY, CEILING(CAST(CLC.Short AS REAL)), MBOL.EditDate ) END      
                         END      
               END      
         )    
         ELSE DATEADD(DAY, CONVERT(INT, CASE WHEN CLC1.Short IS NULL THEN ISNULL(ORDERS.Userdefine01,'0') ELSE ISNULL(CLC1.Short,'0') END), CONVERT(DATETIME, ORDERS.Userdefine10))END,      
         CASE WHEN ISNULL(CLR5.Short,'N') = 'Y' THEN LTRIM(RTRIM(ISNULL(MAX(ORDERS.C_Contact1),''))) + ' ' + LTRIM(RTRIM(ISNULL(MAX(ORDERS.C_Phone1),'')))    
                                                ELSE CAST(ORDERS.Notes as Char(255)) END as Notes,        
         RTRIM(CAST(STORER.notes1 as Char(255))) + SPACE(1) + RTRIM(CAST(STORER.notes2 as Char(255))) As Remarks,              
         ORDERS.C_City,       
         Orders.intermodalvehicle,       
         CODELKUP.Short,      
         ShowField = CASE WHEN ISNULL(CLR.Code,'') <> '' THEN 'Y' ELSE 'N' END ,      
         ShowCRD  = CASE WHEN ((ISNULL(STORER.SUSR1,'') = 'CRD' AND ISNULL(ORDERS.userdefine10,'') <> ''      
                              AND (CONVERT(NVARCHAR(10),(CONVERT(DATETIME,ORDERS.userdefine10) +     
                    CONVERT(INT,CASE WHEN CLC1.Short IS NULL AND ORDERS.StorerKey = 'NIKECN' THEN 0 WHEN CLC1.Short IS NULL THEN ORDERS.Userdefine01 ELSE CLC1.Short END)),121))     
                    <  CONVERT(NVARCHAR(10),ORDERS.DeliveryDate,121))) THEN               
            'Y' ELSE 'N' END,       
         CRD = CONVERT(NVARCHAR(10),ORDERS.DeliveryDate,121),       
         LP = CASE WHEN ISNULL(ORDERS.Userdefine02,'')='' THEN CLR2.NOTES2 ELSE CLR2.NOTES END,      
         CT = CASE WHEN ISNULL(ORDERS.Userdefine02,'')='' THEN CLR1.NOTES2 ELSE CLR1.NOTES END,      
         TL = CASE WHEN ISNULL(ORDERS.Userdefine02,'')='' THEN CLR3.NOTES2 ELSE CLR3.NOTES END,      
         FX = CASE WHEN ISNULL(ORDERS.Userdefine02,'')='' THEN CLR4.NOTES2 ELSE CLR4.NOTES END,      
         [SITE] = '',                       
         CASE WHEN ISNULL(CLR5.Short,'N') = 'Y' THEN (SELECT TOP 1 ISNULL(CL.Description,'')     
                                                      FROM CODELKUP CL (NOLOCK)     
                                                      WHERE CL.LISTNAME = 'RDATA' AND CL.Code = '001') ELSE '' END AS O2,    
         ISNULL(CLR5.Short,'N') AS ShowStorerCols,    
         MAX(ORDERS.ExternPOKey) AS ExternPOKey,    
         CASE WHEN ISNULL(CLR6.Short,'N') = 'Y' AND ISNUMERIC(CLC.Short) = 1 THEN CONVERT(NVARCHAR(30), DATEADD(d,CAST(CLC.Short AS INT),MBOL.AddDate), 121) ELSE NULL END AS NewETA      
         ,@c_PrefixPsn AS PrefixPsn
      FROM  MBOL (NOLOCK)      
      JOIN MBOLDETAIL (NOLOCK) ON (MBOL.Mbolkey = MBOLDETAIL.Mbolkey )         
      INNER JOIN ORDERS (NOLOCK)ON (MBOLDETAIL.Orderkey = Orders.Orderkey)      
      INNER JOIN PACKHEADER (NOLOCK) ON (ORDERS.Storerkey = PACKHEADER.Storerkey AND ORDERS.Loadkey = PACKHEADER.Loadkey)      
      INNER JOIN PACKDETAIL (NOLOCK) ON (PACKHEADER.Storerkey = PACKDETAIL.Storerkey AND PACKHEADER.Pickslipno = PACKDETAIL.Pickslipno)       
      INNER JOIN PICKHEADER (NOLOCK) ON (PACKHEADER.Pickslipno = PICKHEADER.Pickheaderkey)      
      LEFT OUTER JOIN CODELKUP CLC (NOLOCK) ON (CLC.LONG = ORDERS.Facility AND       
                                                CLC.Description = ORDERS.c_City AND      
                                                CLC.ListName = @c_CodeCityLdTime AND         
                                                CAST(CLC.Notes AS char(30)) = Orders.intermodalvehicle)       
      LEFT OUTER JOIN CODELKUP CLC1 (NOLOCK) ON (CLC1.LONG = ORDERS.Facility AND   CLC1.[Description] = ORDERS.C_City AND      
                                                 CLC1.ListName = @c_CodeCityLdTime AND    
                                                 CLC1.Storerkey = ORDERS.StorerKey)     
   
      LEFT OUTER JOIN CODELKUP (NOLOCK) ON (CODELKUP.Listname = 'STRDOMAIN' AND      
                                            CODELKUP.Code = ORDERS.StorerKey)       
      LEFT OUTER JOIN STORER (NOLOCK) ON (STORER.StorerKey = ORDERS.ConsigneeKey)       
      LEFT OUTER JOIN Codelkup CLR (NOLOCK) ON (ORDERS.Storerkey = CLR.Storerkey AND CLR.Code = 'SHOWFIELD'                                              
                                            AND CLR.Listname = 'REPORTCFG' AND CLR.Long = 'r_dw_dmanifest_sum10' AND ISNULL(CLR.Short,'') <> 'N')      
      LEFT OUTER JOIN CODELKUP CLR1 (NOLOCK) ON (ORDERS.Storerkey = CLR1.Storerkey AND CLR1.Listname = 'REPORTCFG'        
                                             AND CLR1.Long = 'r_dw_dmanifest_sum10' AND CLR1.Code = 'ShowCTName' AND ISNULL(CLR1.Short,'') <> 'N')      
      LEFT OUTER JOIN CODELKUP CLR2 (NOLOCK) ON (ORDERS.Storerkey = CLR2.Storerkey AND CLR2.Listname = 'REPORTCFG'        
                                             AND CLR2.Long = 'r_dw_dmanifest_sum10' AND CLR2.Code = 'ShowLPName' AND ISNULL(CLR2.Short,'') <> 'N')      
      LEFT OUTER JOIN CODELKUP CLR3 (NOLOCK) ON (ORDERS.Storerkey = CLR3.Storerkey AND CLR3.Listname = 'REPORTCFG'        
                                             AND CLR3.Long = 'r_dw_dmanifest_sum10' AND CLR3.Code = 'ShowTLName' AND ISNULL(CLR3.Short,'') <> 'N')      
      LEFT OUTER JOIN CODELKUP CLR4 (NOLOCK) ON (ORDERS.Storerkey = CLR4.Storerkey AND CLR4.Listname = 'REPORTCFG'        
                                             AND CLR4.Long = 'r_dw_dmanifest_sum10' AND CLR4.Code = 'ShowFXName' AND ISNULL(CLR4.Short,'') <> 'N')                                                    
      LEFT OUTER JOIN CODELKUP CLR5 (NOLOCK) ON (ORDERS.Storerkey = CLR5.Storerkey AND CLR5.Listname = 'REPORTCFG'        
                                             AND CLR5.Long = 'r_dw_dmanifest_sum10' AND CLR5.Code = 'ShowStorerCols' AND ISNULL(CLR5.Short,'') <> 'N')       
                                             AND CLR5.Code2 = ORDERS.Facility     
      LEFT OUTER JOIN CODELKUP CLR6 (NOLOCK) ON (ORDERS.Storerkey = CLR6.Storerkey AND CLR6.Listname = 'REPORTCFG'        
                                             AND CLR6.Long = 'r_dw_dmanifest_sum10' AND CLR6.Code = 'ShowNewETA' AND ISNULL(CLR6.Short,'') <> 'N')      
                                             AND CLR6.Code2 = ORDERS.Facility         
      WHERE ( MBOL.MbolKey = @c_mbolKey)      
      AND   ( RTRIM(PackHeader.OrderKey) IS NULL OR RTRIM(PackHeader.OrderKey) = '')       
      GROUP BY PackHeader.Storerkey, PackHeader.Pickslipno,      
               Packdetail.CartonNo,      
               MBOL.AddWho,         
               MBOL.MbolKey,         
               MBOL.BookingReference,         
               MBOL.OtherReference,         
               MBOL.PlaceOfLoading,         
               MBOL.PlaceOfDischarge,         
               MBOL.EffectiveDate,         
               MBOL.CarrierKey,         
               MBOL.Vessel,         
               MBOL.VoyageNumber,         
               MBOL.DRIVERName,         
               MBOL.Editdate,        
               ORDERS.Loadkey,    
               ORDERS.DeliveryDate,      
               MBOL.Facility,      
               Pickheader.Zone,      
               MBOL.EditDate,      
               CLC.Short,      
               CAST(ORDERS.Notes as Char(255)),        
               RTRIM(CAST(STORER.notes1 as Char(255))) + SPACE(1) + RTRIM(CAST(STORER.notes2 as Char(255))),      
               ORDERS.C_City,      
               Orders.intermodalvehicle,       
               CODELKUP.Short,      
               ORDERS.Userdefine01,      
               ORDERS.Userdefine04,      
               ORDERS.ExternPOKey,      
               ISNULL(CLR.Code,''),      
               ISNULL(STORER.SUSR1,'') ,      
               substring(ORDERS.ExternPOKey,1,4) + '-' + substring(ORDERS.ExternPOKey,5,2) + '-' + substring(ORDERS.ExternPOKey,7,2),      
               CASE WHEN ISNULL(ORDERS.Userdefine02,'')='' THEN CLR2.NOTES2 ELSE CLR2.NOTES END,      
               CASE WHEN ISNULL(ORDERS.Userdefine02,'')='' THEN CLR1.NOTES2 ELSE CLR1.NOTES END,      
               CASE WHEN ISNULL(ORDERS.Userdefine02,'')='' THEN CLR3.NOTES2 ELSE CLR3.NOTES END,      
               CASE WHEN ISNULL(ORDERS.Userdefine02,'')='' THEN CLR4.NOTES2 ELSE CLR4.NOTES END      
               ,ORDERS.userdefine10,        
               ISNULL(CLR5.Short,'N'),    
               CASE WHEN ISNULL(CLR6.Short,'N') = 'Y' AND ISNUMERIC(CLC.Short) = 1 THEN CONVERT(NVARCHAR(30), DATEADD(d,CAST(CLC.Short AS INT),MBOL.AddDate), 121) ELSE NULL END,              
               CLC1.Short,          
               ORDERS.StorerKey,
					ORDERS.Type,			--ML01
					ORDERS.C_Company,		--ML01
					ORDERS.M_Company	   --ML01
   END          
END        

GO