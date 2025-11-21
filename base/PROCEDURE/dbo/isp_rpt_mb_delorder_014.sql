SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/    
/* Stored Procedure: ISP_RPT_MB_DELORDER_014                               */    
/* Creation Date: 29-SEP-2023                                              */    
/* Copyright: Maersk                                                       */    
/* Written by: CSCHONG                                                     */    
/*                                                                         */    
/* Purpose: WMS-23580 TH- RC customize Delivery Note Report                */    
/*                                                                         */    
/* Called By: RPT_MB_DELORDER_014                                          */    
/*                                                                         */    
/* GitLab Version: 1.0                                                     */    
/*                                                                         */    
/* Version: 1.0                                                            */    
/*                                                                         */    
/* Data Modifications:                                                     */    
/*                                                                         */    
/* Updates:                                                                */    
/* Date            Author          Ver     Purposes                        */
/* 29-SEP-2023     CSCHONG         1.1     Devops Scripts Combine          */
/***************************************************************************/ 

CREATE   PROC [dbo].[ISP_RPT_MB_DELORDER_014]
     @c_mbolkey                  NVARCHAR(20)

AS  
BEGIN
   SET NOCOUNT ON   
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF 

   DECLARE @n_continue    int,
           @c_errmsg      NVARCHAR(255),
           @b_success     int,
           @n_err         int,
           @b_debug       INT,
           @c_RLine1      NVARCHAR(150),
           @c_RLine2      NVARCHAR(150),
           @c_RLine3      NVARCHAR(150),
           @c_RLine4      NVARCHAR(150),
           @c_RLine5      NVARCHAR(150),
           @c_showRline   NVARCHAR(1) = 'N'

      DECLARE @n_cnt INT

      DECLARE @c_storerkey NVARCHAR(20)

      SELECT TOP 1 @c_storerkey = OH.StorerKey
      FROM  ORDERS OH  WITH (NOLOCK) 
      WHERE OH.MBOLKey=@c_MBOLKey 
    
    IF EXISTS (SELECT 1 FROM CODELKUP CL WITH (NOLOCK)
               WHERE CL.ListName = 'DelText' AND CL.Storerkey = @c_storerkey)
     BEGIN
        SET @c_showRline = 'Y'
     END
  
      SELECT @c_RLine1 = ISNULL(MAX(CASE WHEN CL.Code = '01'  THEN ISNULL(RTRIM(CL.Description),'') ELSE '' END),'')
            ,@c_RLine2 = ISNULL(MAX(CASE WHEN CL.Code = '02'  THEN ISNULL(RTRIM(CL.Description),'') ELSE '' END),'')
            ,@c_RLine3 = ISNULL(MAX(CASE WHEN CL.Code = '03'  THEN ISNULL(RTRIM(CL.Description),'') ELSE '' END),'')
            ,@c_RLine4 = ISNULL(MAX(CASE WHEN CL.Code = '04'  THEN ISNULL(RTRIM(CL.Description),'') ELSE '' END),'')
            ,@c_RLine5 = ISNULL(MAX(CASE WHEN CL.Code = '05'  THEN ISNULL(RTRIM(CL.Description),'') ELSE '' END),'')
     FROM CODELKUP CL WITH (NOLOCK)
     WHERE CL.ListName = 'DelText' AND CL.Storerkey = @c_storerkey

  

  
            SELECT DISTINCT ISNULL(SCT.refno,'') AS SCT_Refno,
                            Orderkey = OH.OrderKey,
                             M.CarrierKey AS Carrierkey, 
                             ISNULL(M.DRIVERName,'') AS DriverName, 
                             externorderkey = OH.ExternOrderKey, 
                             M.Vessel AS Vessel,
                             MD.MbolKey AS mbolkey, 
                             M.ShipDate AS ShipDate,
                             OH.ConsigneeKey AS consigneekey, 
                             OH.DeliveryDate AS OHDeliveryDate, 
                             OH.C_Company AS c_comapany,
                             OH.Route AS OHROUTE,
                             ISNULL(OH.C_Address1,'') AS c_address1, 
                             ISNULL(OH.C_Address2,'') AS c_address2, 
                             ISNULL(OH.C_Address3,'') AS c_address3, 
                             ISNULL(OH.C_Address4,'') AS c_address4, 
                             ISNULL(OH.C_City,'') AS c_city, 
                             ISNULL(OH.C_State,'') AS c_state, 
                             ISNULL(OH.C_Zip,'') AS c_zip, 
                             ISNULL(OH.C_Phone1,'') AS c_phone1,
                             ISNULL(OH.C_Phone2,'') AS c_phone2,
                             M.OtherReference AS Othref , 
                             CASE WHEN (OH.InvoiceAmount)=0 then '' else  Concat ((OH.PmtTerm),' ',(OH.InvoiceAmount)) END AS Sealno2,
                             CASE WHEN ISNULL(C.code2,'') <> '' THEN OH.Userdefine09 ELSE  OH.storerkey END AS storerkey,
                             OH.ExternPOKey AS ExtPokey, 
                             Case When OH.Type not in ('TMS-R','BGT-R') Then MD.TotalCartons ELSE 0 END AS ttlctn, 
                             Case When OH.Type in ('TMS-R','BGT-R') Then MD.TotalCartons ELSE 0 END AS QtyRtn, 
                             OH.UserDefine10  AS DocRtn, 
                             LTRIM(ISNULL(OH.Notes,'') + ' ' + ISNULL(OH.Notes2,'')   ) AS OHNotes,   
                             ISNULL(F.Address2,'') AS FADDress2, 
                             ISNULL(F.Address3,'') AS FAddress3,
                             ISNULL(F.Address4,'') AS FAddress4, 
                             ISNULL(F.City,'') AS FCity, 
                             ISNULL(F.Zip,'') AS FZip,
                             contact1 = ISNULL(OH.c_contact1,''),
                             rpttitle =   case when isnull(c2.long,'') <> '' THEN c2.long ELSE c3.long END,
                             ISNULL(C4.SHORT,'') AS SHOWFIXTEXT,
                             ISNULL(C4.NOTES,'') AS SHOWTEXT,
                             @c_RLine1 AS RLine1,  
                             @c_RLine2 AS RLine2,
                             @c_RLine3 AS RLine3,  
                             @c_RLine4 AS RLine4,    
                             @c_RLine5 AS RLine5, 
                             @c_showRline AS ShowRLine,
                             ISNULL(ST.Notes1,'') AS STNotes1,
                             ISNULL(ST.Notes2,'') AS STNotes2,
                             ISNULL(C5.SHORT,'N') AS SHOWQrcodenotes1,
                             ISNULL(C6.SHORT,'N') AS SHOWQrcodenotes2
            FROM MBOLDETAIL MD WITH (NOLOCK)
            JOIN ORDERS OH  WITH (NOLOCK) ON MD.MbolKey=OH.MBOLKey AND MD.OrderKey=OH.OrderKey 
            JOIN FACILITY F WITH (NOLOCK) ON F.Facility=OH.Facility
            JOIN MBOL M WITH (NOLOCK) ON M.MbolKey=MD.MbolKey
            LEFT JOIN RDT.rdtScanToTruck SCT WITH (NOLOCK) ON SCT.Mbolkey = OH.OrderKey
            LEFT OUTER JOIN STORER ST ON (OH.ConsigneeKey=ST.StorerKey)
            LEFT JOIN CODELKUP C WITH (NOLOCK) ON C.listname = 'LKRPDM' and C.storerkey=OH.storerkey and c.code='001'
            LEFT JOIN CODELKUP C2 WITH (NOLOCK) ON C2.listname = 'LKRPDM' and C2.code='002' and C2.storerkey=OH.storerkey and C2.code2 = OH.type
            LEFT JOIN CODELKUP C3 WITH (NOLOCK) ON C3.listname = 'LKRPDM' and C3.code='002' and C3.storerkey = '' and c3.code2=''
            LEFT JOIN CODELKUP C4 WITH (NOLOCK) ON C4.listname = 'REPORTCFG' and C4.storerkey = OH.storerkey and C4.long = 'RPT_MB_DELORDER_014'
            LEFT JOIN CODELKUP C5 WITH (NOLOCK) ON C5.listname = 'REPORTCFG' and C5.storerkey = OH.storerkey and C5.long = 'RPT_MB_DELORDER_014' AND C5.Code='SHOWQRCODESTNotes1'
            LEFT JOIN CODELKUP C6 WITH (NOLOCK) ON C6.listname = 'REPORTCFG' and C6.storerkey = OH.storerkey and C6.long = 'RPT_MB_DELORDER_014' AND C6.Code='SHOWQRCODESTNotes2'
             WHERE OH.MBOLKey=@c_MBOLKey 
            ORDER BY  MBOLKey desc,oh.OrderKey

END      

GO