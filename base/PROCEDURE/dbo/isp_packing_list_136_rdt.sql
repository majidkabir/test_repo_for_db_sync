SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/******************************************************************************/              
/* Store Procedure: isp_Packing_List_136_rdt                                  */              
/* Creation Date: 19-JUN-2023                                                 */              
/* Copyright: IDS                                                             */              
/* Written by: CHONGCS                                                        */              
/*                                                                            */              
/* Purpose: WMS-22864 [TW]PUMA_RDT DiffReport_New                             */  
/*                                                                            */ 
/*                                                                            */              
/*                                                                            */              
/* Called By:  r_dw_packing_list_136_rdt                                      */              
/*                                                                            */              
/* PVCS Version: 1.0                                                          */              
/*                                                                            */              
/* Version: 1.0                                                               */              
/*                                                                            */              
/* Data Modifications:                                                        */              
/*                                                                            */              
/* Updates:                                                                   */              
/* Date         Author    Ver.  Purposes                                      */    
/* 19-Jun-2022  CSCHONG   1.0   Devops Scripts Combine                        */
/******************************************************************************/     
  
CREATE   PROC [dbo].[isp_Packing_List_136_rdt]             
             (@c_pickslipno NVARCHAR(20),
              @c_labelno  NVARCHAR(20)='')    
            
AS            
BEGIN            
   SET NOCOUNT ON            
   SET ANSI_WARNINGS OFF            
   SET QUOTED_IDENTIFIER OFF            
   SET CONCAT_NULL_YIELDS_NULL OFF    
  
   DECLARE @c_MCompany        NVARCHAR(45)  
         , @c_Externorderkey  NVARCHAR(30)  
         , @c_C_Addresses     NVARCHAR(200)   
         , @c_loadkey         NVARCHAR(10)  
         , @c_Userdef03       NVARCHAR(20)  
         , @c_salesman        NVARCHAR(30)  
         , @c_phone1          NVARCHAR(18)
         , @c_contact1        NVARCHAR(30)  
  
         , @n_TTLQty          INT   
         , @c_shippername     NVARCHAR(45)  
         , @c_Sku             NVARCHAR(20)  
         , @c_Size            NVARCHAR(5)  
         , @c_PickLoc         NVARCHAR(10) 
         , @n_NoOfLine        INT  
         , @c_getOrdKey       NVARCHAR(10)
         , @n_ctnrec          INT = 0
         , @n_maxrecgrp       INT
         , @n_AddRec          INT

DECLARE @c_Addwho    NVARCHAR(128)
       ,@c_Fullname  NVARCHAR(80)
       ,@d_Adddate   DATETIME
       ,@d_PrnDate   DATETIME
       ,@n_PACKQTY   INT
       ,@n_QtyDiff   INT

 SET @n_NoOfLine = 5
 SET @c_getOrdKey = ''       

        
  
 CREATE TABLE #PACKLIST136rdt 
         ( Seqno           INT NOT NULL IDENTITY(1,1) PRIMARY KEY
         , Loadkey         NVARCHAR(30) NULL   
         , Dropid          NVARCHAR(20) NULL  
         , RDTUserID       NVARCHAR(256) NULL  
         , RDTUserName     NVARCHAR(256) NULL 
         , SKU             NVARCHAR(20)  NULL 
         , Pickqty         INT     
         , Packqty         INT          
         , OrderKey        NVARCHAR(10)  NULL     
         , CCompany        NVARCHAR(45)  NULL        
         , consigneekey    NVARCHAR(45)  NULL        
         , Pickslipno      NVARCHAR(20)  NULL  
         , Labelno         NVARCHAR(20)
         , RecGrp          INT
         , SDESCR          NVARCHAR(120)   
         , PackDate        DATETIME 
         , PrnDate         DATETIME         
         )  


         SELECT TOP 1 @c_Addwho = PD.AddWho
                      ,@d_Adddate = PD.AddDate
         FROM PACKDETAIL PD (NOLOCK)
         WHERE PD.LabelNo = @c_labelno

         SELECT @n_PACKQTY = SUM(PD.qty)
         FROM PACKDETAIL PD (NOLOCK)
         WHERE PD.LabelNo = @c_labelno


         SELECT @c_Fullname = FullName
         FROM RDT.RDTUser (NOLOCK)
         WHERE UserName = @c_Addwho


         SET @d_PrnDate = GETDATE()


        -- SELECT @c_Addwho,@d_Adddate,@c_Fullname,@d_PrnDate,@n_PACKQTY
          
   INSERT INTO #PACKLIST136rdt
   (
       Loadkey,
       Dropid,
       RDTUserID,
       RDTUserName,
       SKU,
       Pickqty,
       Packqty,
       OrderKey,
       CCompany,
       consigneekey,
       Pickslipno,
       Labelno,
       RecGrp,
       SDESCR,
       PackDate,PrnDate
   )             
SELECT OH.LoadKey 
      ,PID.DropID 
      ,@c_Addwho      AS RDTUserID
      ,@c_Fullname    AS RDTUserName 
      , PID.Sku
      , SUM(PID.qty) AS Pickqty
      ,@n_PACKQTY
      ,OH.OrderKey
      ,OH.C_Company
      ,OH.ConsigneeKey
      ,@c_pickslipno AS Pickslipno
      ,@c_labelno AS Labelno,1
      ,S.DESCR
      ,@d_Adddate,@d_PrnDate
FROM dbo.PickHeader PH (NOLOCK)
JOIN Pickdetail PID WITH (NOLOCK) ON PID.OrderKey=PH.OrderKey
--JOIN Packdetail PAD WITH (NOLOCK) ON PAD.LabelNo = PID.DropID
JOIN ORDERS OH (NOLOCK) ON OH.OrderKey = PH.OrderKey
JOIN SKU S WITH (NOLOCK) ON s.StorerKey = PID.StorerKey AND S.sku = PID.SKU
--LEFT JOIN RDT.RDTUser RU WITH (NOLOCK) ON RU.UserName = PAD.AddWho 
WHERE PID.DropID = @c_labelno
GROUP BY OH.LoadKey 
      ,PID.DropID 
      ,OH.ConsigneeKey
      ,OH.OrderKey
      ,OH.C_Company
      , PID.Sku
      ,S.DESCR


   SET @n_AddRec = @n_NoOfLine -(@n_ctnrec%@n_NoOfLine)

  
  
      SELECT       Loadkey,
                   Dropid,
                   RDTUserID,
                   RDTUserName,
                   SKU,
                   Pickqty,
                   OrderKey,
                   Packqty,
                   CCompany,
                   PrnDate,
                   consigneekey,
                   Pickslipno,
                   Labelno,
                   RecGrp,
                   SDESCR,
                   PackDate,
                   (Pickqty-Packqty) AS QtyDiff 
         FROM #PACKLIST136rdt  
         ORDER BY Pickslipno,Labelno
END

GO