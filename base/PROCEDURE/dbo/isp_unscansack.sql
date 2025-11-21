SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

 
/************************************************************************/          
/* Stored Procedure: isp_UnscanSack                                     */          
/* Creation Date: 29-DEC-2015                                           */          
/* Copyright: IDS                                                       */          
/* Written by: CSCHONG                                                  */          
/*                                                                      */          
/* Purpose: Unscanned Sack Report                                       */          
/*                                                                      */          
/*                                                                      */          
/* Called By: r_dw_UnscanSack                                           */          
/*                                                                      */          
/* PVCS Version: 1.0                                                    */          
/*                                                                      */          
/* Version: 1.0                                                         */          
/*                                                                      */          
/* Data Modifications:                                                  */          
/*                                                                      */          
/* Updates:                                                             */          
/* Date         Author Ver Purposes                                     */       
/************************************************************************/          
CREATE PROC [dbo].[isp_UnscanSack]       
(      
   @c_MBOLKey   NVARCHAR(10)      
)          
AS          
BEGIN      
   SET NOCOUNT ON          
   SET QUOTED_IDENTIFIER OFF          
   SET ANSI_NULLS ON          
   SET CONCAT_NULL_YIELDS_NULL OFF      
          
   DECLARE   @c_Route      NVARCHAR(10)      
            ,@n_Expected   INT      
            ,@n_Totes      INT      
            ,@d_AddDate    DateTime -- (ChewKP01)    
            ,@c_AddWho     NVARCHAR(18)    
            ,@c_PlaceOfLoadingQualifier NVARCHAR(10)    
            ,@n_UnPackTote   INT  
            ,@c_loadkey      NVARCHAR(15)  
            ,@c_getOrderkey  NVARCHAR(15)  
            ,@n_sacknotscan  INT  
            ,@c_Sackno       NVARCHAR(30)  
            ,@c_Store        NVARCHAR(30)  
            ,@n_qty          INT  
            ,@n_TTLSACK      INT  
            --,@d_adddate      DATETIME,  
            ,@c_user         NVARCHAR(15)  
          
   SET @n_Expected = 0      
   SET @c_AddWho = ''    
   SET @c_PlaceOfLoadingQualifier = ''  
   SET @n_UnPackTote   = 0   
    
  
  
 DECLARE @t_Unscanned_Sack TABLE (                 
          Mbolkey            NVARCHAR(18) NULL,  
         -- AltSKU             NVARCHAR(15) NULL,   
          OrdRoute           NVARCHAR(10) NULL,  
          Adddate          DateTime ,  
          Addwho           NVARCHAR(15) NULL,  
          [User]             NVARCHAR(15) NULL,  
          Expected           INT ,  
          SackNotScan        INT,  
          OrderKey           NVARCHAR(15) NULL,  
          SackNo             NVARCHAR(30) NULL,  
          Store              NVARCHAR(30) NULL,  
          Qty                INT DEFAULT 0  
            
  
       )     
  
DECLARE @t_Unscanned_Pallet TABLE (                 
          Mbolkey            NVARCHAR(18) NULL,  
          OrderKey           NVARCHAR(15) NULL,  
          SackNo             NVARCHAR(30) NULL,  
          Store              NVARCHAR(30) NULL,  
          Qty                INT)  
  
  
   SET @c_loadkey = ''  
   SET @c_user = ''  
   SET @d_adddate = ''  
  
   SELECT TOP 1 @c_loadkey = ORD.Loadkey  
                ,@d_adddate = MB.Adddate  
                ,@c_user = MB.Addwho  
   FROM ORDERS ORD WITH (NOLOCK)  
   JOIN mboldetail MBD WITH (NOLOCK) ON MBD.Orderkey=ORD.Orderkey  
   JOIN MBOL MB WITH (NOLOCK) ON MB.mbolkey = MBD.mbolkey  
   WHERE MBD.Mbolkey=@c_MBOLKey  
                
                   
   INSERT INTO @t_Unscanned_Sack      
   SELECT DISTINCT @c_MBOLKey--, pid.altsku  
          ,'',@d_adddate,@c_user,SUSER_SNAME() as [user]  
          ,0 as Expected,0 as SackNotScan,CSD.Orderkey,pid.Altsku  
          ,ORD.Consigneekey,0  
--   FROM pickdetail pid WITH (NOLOCK)  
--   JOIN mboldetail md WITH (NOLOCK) ON pid.orderkey = md.orderkey  
--   JOIN MBOL MB WITH (NOLOCK) ON MB.mbolkey=md.mbolkey  
--   JOIN rdt.rdtscantotruck r WITH (NOLOCK) ON md.mbolkey = r.mbolkey  
--   JOIN ORDERS ORD WITH (NOLOCK) ON ORD.Orderkey = md.orderkey  
--   JOIN cartonshipmentdetail CSD WITH (NOLOCK) ON CSD.Loadkey=ORD.Loadkey AND CSD.Orderkey = ORD.Orderkey   
   FROM pickdetail pid WITH (NOLOCK)  
   LEFT JOIN palletdetail PAD WITH (NOLOCK) ON PAD.userdefine05 = pid.altsku  
   LEFT JOIN ORDERS ORD WITH (NOLOCK) ON ORD.Orderkey = pid.orderkey   
  --LEFT JOIN mboldetail md WITH (NOLOCK) ON pid.orderkey = md.orderkey  
  -- LEFT JOIN MBOL MB WITH (NOLOCK) ON MB.mbolkey=md.mbolkey  
   LEFT JOIN rdt.rdtscantotruck r WITH (NOLOCK) ON  r.loadkey = ORD.loadkey --md.mbolkey = r.mbolkey   
   LEFT JOIN cartonshipmentdetail CSD WITH (NOLOCK) ON CSD.Loadkey=ORD.Loadkey AND CSD.Orderkey = ORD.Orderkey  
   --WHERE md.mbolkey = @c_MBOLKey  
   WHERE ord.loadkey = @c_loadkey  
   AND pid.status >= '5'  
   AND ISNULL( pid.altsku, '') <> ''  
   AND NOT EXISTS (  
   SELECT 1 from palletdetail pld WITH (NOLOCK) WHERE pld.userdefine05 = pid.altsku and pld.userdefine03 = @c_MBOLKey and userdefine04 <> 'ecomm')  
   --ORDER BY md.mbolkey desc   
  
  
--    CartonType = 'STORE'      
   SELECT @n_Expected = COUNT(DISTINCT UCCLabelNo)       
   FROM CartonShipmentDetail WITH (NOLOCK)   
   WHERE Loadkey = @c_loadkey      
     
     
     
   /*   SELECT @n_sacknotscan = COUNT(refno)  
      FROM rdt.rdtscantotruck r WITH (NOLOCK)   
      WHERE CartonType = 'STORE'   
      AND r.mbolkey = @c_mbolkey  
      AND r.loadkey = @c_loadkey  
      AND NOT EXISTS  
      (SELECT 1 FROM transmitlog2 TL2 (NOLOCK) WHERE r.refno = tl2.key1 and tablename = 'TNTSHPREQ')*/  
  
   SELECT @n_sacknotscan = count(refno)  
   FROM rdt.rdtscantotruck r (nolock)   
   JOIN mbol m (nolock) on r.mbolkey = m.mbolkey   
   WHERE CartonType = 'STORE'   
   AND m.mbolkey  = @c_mbolkey  
   AND NOT EXISTS  
   (SELECT 1 FROM transmitlog2 TL2 (nolock) where r.refno = tl2.key1 and tablename = 'TNTSHPREQ')  
  
  

  UPDATE @t_Unscanned_Sack  
  SET Expected = @n_Expected,  
      SackNotScan = CASE WHEN @n_sacknotscan = 0 THEN 0 ELSE (@n_Expected-@n_sacknotscan) END
  WHERE Mbolkey = @c_mbolkey  
        
       
  
 /*  INSERT INTO @t_Unscanned_Pallet    
   SELECT DISTINCT PAD.UserDefine03 as Mbolkey,ORD.Orderkey as Orderkey,  
                   pd.altsku as sackno,--PAD.UserDefine05 as SackNo,   
                   PAD.UserDefine04 as Store,0 as qty   
   FROM palletdetail PAD WITH (NOLOCK)  
    LEFT JOIN PICKDETAIL PD WITH (NOLOCK) ON PD.altsku = PAD.userdefine05  
   LEFT JOIN ORDERS ORD WITH (NOLOCK) ON ORD.Orderkey=Pd.Orderkey  
   --LEFT JOIN @t_Unscanned_Sack US ON US.Orderkey = PD.Orderkey  
   WHERE PAD.UserDefine03 = @c_mbolkey   
   --AND   
   AND PAD.userdefine04 <> 'ecomm'*/  
  
   DECLARE C_Unscanned_Pallet CURSOR LOCAL FAST_FORWARD READ_ONLY FOR   
   SELECT DISTINCT SackNo  
   FROM @t_Unscanned_Sack  
   WHERE mbolkey = @c_mbolkey  
  
   OPEN C_Unscanned_Pallet   
   FETCH NEXT FROM C_Unscanned_Pallet INTO @c_Sackno  
  
   WHILE (@@FETCH_STATUS <> -1)   
   BEGIN   
        
   SELECT @n_qty = COUNT(DISTINCT UserDefine05)       
   FROM palletdetail  WITH (NOLOCK)      
   WHERE UserDefine03 = @c_MBOLKey      
   --AND UserDefine05 = @c_Sackno  

   SELECT @c_PlaceOfLoadingQualifier = PlaceOfLoadingQualifier
   FROM MBOL M WITH (NOLOCK)
   WHERE mbolkey = @c_MBOLKey  
  
   UPDATE @t_Unscanned_Sack  
   SET qty = 1--@n_qty  
      ,ordroute = @c_PlaceOfLoadingQualifier
   WHERE Mbolkey = @c_mbolkey  
   AND SackNo = @c_Sackno  
     
     
   FETCH NEXT FROM C_Unscanned_Pallet INTO @c_Sackno  
   END   
  
   CLOSE C_Unscanned_Pallet  
   DEALLOCATE C_Unscanned_Pallet      
                       
    
   DECLARE @t_UnScanTote TABLE (                 
          Expected   INT,   
          Totes         INT,  
          MBOLKEY       NVARCHAR(10),  
          AddDate       DATETIME,  
          [User]        NVARCHAR(18),  
          POLQ          NVARCHAR(10),  
          DropID        NVARCHAR(18),  
          Consigneekey  NVARCHAR(15),  
          ExternOrderkey NVARCHAR(30),  
          OrderLineNo    NVARCHAR(5),  
          SKU           NVARCHAR(20),  
          Qty           INT,  
          UserName      NVARCHAR(18)  
            
       )         
     
   
     
     
--   SELECT DISTINCT * FROM @t_Unscanned_Sack   
--   SELECT DISTINCT * FROM @t_Unscanned_Pallet   
   
   SELECT DISTINCT  S.Expected ,  
                    S.Mbolkey,             
                  -- S.AltSKU,                      
                    S.Adddate,  
                    S.Addwho,  
                    S.OrdRoute,                     
                    S.SackNotScan,  
                    S.OrderKey,  
                    S.SackNo,  
                    S.Store,  
                    S.Qty,   
                    S.[User]                      
   FROM @t_Unscanned_Sack S  
   --JOIN @t_Unscanned_Pallet P ON P.mbolkey = S.mbolkey AND P.Orderkey=S.Orderkey  
   --CROSS APPLY (select DIsTINCT   
     
  
--DROP TABLE @t_Unscanned_Pallet    
END -- procedure  
  
--DROP TABLE @t_Unscanned_Sack  


SET QUOTED_IDENTIFIER OFF  

GO