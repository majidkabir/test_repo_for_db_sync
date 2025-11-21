SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/******************************************************************************/                
/* Store Procedure: isp_Packing_List_32                                       */                
/* Creation Date: 10-Jan-2017                                                 */                
/* Copyright: IDS                                                             */                
/* Written by: CSCHONG                                                        */                
/*                                                                            */                
/* Purpose: WMS-915 - CN Carter's wholesale Packing list                      */    
/*                                                                            */                
/*                                                                            */                
/* Called By:  r_dw_packing_list_32                                           */                
/*                                                                            */                
/* PVCS Version: 1.0                                                          */                
/*                                                                            */                
/* Version: 1.0                                                               */                
/*                                                                            */                
/* Data Modifications:                                                        */                
/*                                                                            */                
/* Updates:                                                                   */                
/* Date         Author    Ver.  Purposes                                      */    
/* 28-Jan-2019  TLTING_ext 1.1  enlarge externorderkey field length      */  
/******************************************************************************/       
    
CREATE PROC [dbo].[isp_Packing_List_32]               
       (@c_MBOLKey NVARCHAR(20))                
AS              
BEGIN                         
   SET ANSI_WARNINGS OFF              
   SET NOCOUNT ON   
   SET ANSI_NULLS OFF   
   SET QUOTED_IDENTIFIER OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF   
    
   DECLARE @n_TTLPDQty        INT     
         , @c_labelno         NVARCHAR(45)    
         , @n_TTLSKU          INT  
         , @n_Wgt             FLOAT  
         , @c_ExtOrdkey       NVARCHAR(50)  --tlting_ext  
         , @c_Issue           NVARCHAR(1)  
    
    
 CREATE TABLE #PACKLIST32  
         ( WHCODE          NVARCHAR(50) NULL  
         , ShipFrom        NVARCHAR(50) NULL   
         , ShipFromAdd     NVARCHAR(45) NULL  
         , ShipCompany     NVARCHAR(45) NULL  
         , ShipAdd         NVARCHAR(45) NULL  
         , ExtOrdkey       NVARCHAR(30) NULL  
         , Shipkey         NVARCHAR(15)  NULL   
         , ShipDate        DATETIME NULL  
         , CONTAINER_NO    NVARCHAR(30) NULL   
         , MBKey           NVARCHAR(10)  NULL  
         , M_Company       NVARCHAR(45) NULL   
         , MStateCity      NVARCHAR(90) NULL  
         , ExtPOKey        NVARCHAR(20) NULL  
         , SKUStyle        NVARCHAR(20) NULL  
         , SKUColor        NVARCHAR(20) NULL  
         , SMeasurement    NVARCHAR(10) NULL  
         , SKUSize         NVARCHAR(10) NULL     
         , Department      NVARCHAR(20) NULL   
         , Labelno         NVARCHAR(20)  NULL  
         , Pqty            INT   NULL               
         , CntCarton       INT   NULL  
         , Wgt             FLOAT NULL     
         , RecGrp           INT   NULL  
         )    
           
   INSERT INTO #PACKLIST32 (  
                          WHCODE            
        , ShipFrom          
        , ShipFromAdd       
        , ShipCompany       
        , ShipAdd           
        , ExtOrdkey         
        , Shipkey            
        , ShipDate          
        , CONTAINER_NO                
        , MBKey             
        , M_Company       
        , MStateCity        
        , ExtPOKey          
        , SKUStyle          
        , SKUColor          
        , SMeasurement      
        , SKUSize              
        , Department         
        , Labelno   
        , RecGrp          
             )               
   SELECT  DISTINCT 'DC' + ' ' +C.Code AS 'WHCODE' , STO.SUSR1 AS ShipFrom,  
              FAC.Address1 AS ShipFromAdd,ORD.C_Company AS ShipCompany,  
              ORD.C_Address1 AS ShipAdd,ORD.ExternOrderKey AS ExtOrdkey,  
              ORD.ShipperKey AS Shipkey,MB.EditDate AS shipDate,  
              CON.BookingReference AS CONTAINER_NO,ORD.MBOLKey AS MBKey,  
              ORD.M_COMPANY AS 'M_COMPANY',(ORD.C_state+ ' ' + ORD.C_City) AS 'MStateCity',  
              ORD.Externpokey AS ExtPOKey,S.style AS SKUStyle,S.Color AS SKUColor,  
              s.Measurement AS SKUMeasurement,S.[Size] AS SKUSize,  
              ORD.UserDefine02 AS 'Department',PDET.Labelno AS 'LabelNo',1  
 FROM MBOL MB WITH (NOLOCK)  
 JOIN ORDERS ORD WITH (NOLOCK) ON ORD.MBOLKey=MB.MbolKey  
 LEFT JOIN PackHeader AS PH WITH (NOLOCK) ON PH.loadkey = ORD.loadkey  
 LEFT JOIN PackDetail AS PDET WITH (NOLOCK) ON PDET.PickSlipNo=PH.PickSlipNo  
 LEFT JOIN SKU S WITH (NOLOCK) ON S.StorerKey = PDET.StorerKey AND S.SKU = PDET.SKU  
 LEFT JOIN PACKINFO PI WITH (NOLOCK) ON PI.PickSlipNo=PDET.PickSlipNo AND PI.CartonNo = PDET.CartonNo  
 LEFT JOIN FACILITY AS FAC WITH (NOLOCK) ON FAC.Facility=ORD.Facility  
 LEFT JOIN STORER STO WITH (NOLOCK) ON STO.StorerKey = ORD.StorerKey  
 LEFT JOIN CONTAINER AS CON WITH (NOLOCK) ON CON.MBOLKey=MB.MbolKey  
 LEFT JOIN CODELKUP C WITH (NOLOCK) ON C.LISTNAME='carterfac' AND C.Short=ORD.Facility  
   WHERE MB.MbolKey = @c_MBOLKey  
   AND ORD.Rds = '1'   
     
     
     
   --SELECT * FROM   #PACKLIST32  
  DECLARE PACK_CUR CURSOR FAST_FORWARD READ_ONLY   
  FOR  
     SELECT DISTINCT ExtOrdkey,labelno  
     FROM   #PACKLIST32  
     --ORDER BY ExtOrdkey,Labelno  
   
 OPEN PACK_CUR   
   
 FETCH NEXT FROM PACK_CUR INTO @c_ExtOrdkey,@c_labelno  
   
 WHILE @@FETCH_STATUS = 0  
 BEGIN  
    
  SET @n_TTLSKU = 0  
  SET @n_TTLPDQty = 0  
  SET @n_Wgt = 0.00  
  SET @c_Issue = '0'  
    
  SELECT @n_TTLSKU = COUNT(DISTINCT PDET.SKU)  
         ,@n_TTLPDQty = SUM(PDET.Qty)  
  FROM PackDetail AS PDET WITH (NOLOCK)  
  WHERE PDET.LabelNo = @c_labelno  
    
  SELECT @n_Wgt = SUM(PI.weight)  
  FROM PACKDETAIL PDET (NOLOCK)  
  JOIN PACKINFO PI WITH (NOLOCK) ON PI.PickSlipNo = PDET.PickSlipNo   
                                 AND PI.CartonNo = PDET.CartonNo  
    WHERE PDET.LabelNo = @c_labelno     
      
      
    SELECT @c_Issue = ORD.Issued  
    FROM ORDERS ORD (NOLOCK)  
    WHERE ExternOrderKey = @c_ExtOrdkey  
    AND MBOLKey = @c_MBOLKey  
      
    UPDATE  #PACKLIST32  
    SET  Pqty       =  @n_TTLPDQty  
        ,CntCarton  =  @n_TTLSKU     
        ,Wgt        =  @n_Wgt  
    WHERE MBKey = @c_MBOLKey  
    AND Labelno = @c_labelno    
      
    IF @c_Issue = ''  
    BEGIN  
     SET @c_Issue = '1'  
    END                        
    
  IF @c_Issue = 0   
  BEGIN  
   GOTO QUIT  
  END  
    
  IF @c_Issue = 2  
  BEGIN  
     
   INSERT INTO #PACKLIST32 (  
                          WHCODE            
        , ShipFrom          
        , ShipFromAdd       
        , ShipCompany       
        , ShipAdd           
        , ExtOrdkey         
        , Shipkey            
        , ShipDate          
        , CONTAINER_NO                
        , MBKey             
        , M_Company         
        , MStateCity        
        , ExtPOKey          
        , SKUStyle          
        , SKUColor          
        , SMeasurement      
        , SKUSize              
        , Department         
        , Labelno   
        , Pqty                            
        , CntCarton         
        , Wgt    
        , RecGrp          
             )   
      SELECT    WHCODE            
        , ShipFrom          
        , ShipFromAdd       
        , ShipCompany       
        , ShipAdd           
        , ExtOrdkey         
        , Shipkey            
        , ShipDate          
        , CONTAINER_NO                
        , MBKey             
        , M_Company         
        , MStateCity        
        , ExtPOKey          
        , SKUStyle          
        , SKUColor          
        , SMeasurement      
        , SKUSize              
        , Department         
        , Labelno           
        , Pqty                            
        , CntCarton         
        , Wgt    
        , 2  
      FROM #PACKLIST32   
      WHERE LABELNo = @c_labelno            
     
  END  
   
 FETCH NEXT FROM PACK_CUR INTO @c_ExtOrdkey,@c_labelno   
   END    
     
   CLOSE PACK_CUR   
 DEALLOCATE PACK_CUR   
    
                   SELECT WHCODE            
        , ShipFrom          
        , ShipFromAdd       
        , ShipCompany       
        , ShipAdd           
        , ExtOrdkey         
        , Shipkey            
        , ShipDate          
        , CONTAINER_NO                
        , MBKey             
        , M_Company         
        , MStateCity        
        , ExtPOKey          
        , SKUStyle          
        , SKUColor          
        , SMeasurement      
        , SKUSize              
        , Department         
        , Labelno           
        , Pqty                            
        , CntCarton         
        , Wgt   
        , RecGrp   
      FROM #PACKLIST32    
        --ORDER BY ExtOrdkey,Labelno  
                 
END  
  
QUIT:  

GO