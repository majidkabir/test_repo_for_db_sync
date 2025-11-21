SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/              
/* Stored Procedure: isp_UnscanTote02                                   */              
/* Creation Date: 29-Jul-2010                                           */              
/* Copyright: IDS                                                       */              
/* Written by: GTGOH                                                    */              
/*                                                                      */              
/* Purpose: Unscanned Totes/Bags For Republic                           */              
/*                                                                      */              
/*                                                                      */              
/* Called By: r_dw_unscantote                                           */              
/*                                                                      */              
/* PVCS Version: 1.0                                                    */              
/*                                                                      */              
/* Version: 5.4                                                         */              
/*                                                                      */              
/* Data Modifications:                                                  */              
/*                                                                      */              
/* Updates:                                                             */              
/* Date         Author Ver Purposes                                     */        
/* 07-09-2010   ChewKP 1.1 Only list UnScan Tote for Ecomm (ChewKP01)   */    
/* 14-09-2010   ChewKP 1.2 Bug Fixes : Exclude Shipped Tote (ChewKP02)  */      
/* 20-09-2010   ChewKP 1.3 Revise SP for same OrderGroup different MBOL */    
/*                         (ChewKP03)                                   */ 
/* 25-09-2010   ChewKP 1.4 Expected shall filter by OrderGroup(ChewKP04)*/ 
/* 28-Jan-2019  TLTING_ext 1.5  enlarge externorderkey field length      */    
/************************************************************************/              
CREATE PROC [dbo].[isp_UnscanTote02]           
(          
   @c_OrderGroup  NVARCHAR(20)          
)              
AS              
BEGIN          
   SET NOCOUNT ON 
   SET ANSI_NULLS OFF 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF         
              
   DECLARE   @c_Route         NVARCHAR(10)          
            ,@n_Expected      INT          
            ,@n_Totes         INT          
            ,@c_MBOLKey       NVARCHAR(10)          
            ,@c_MBOLAddWho    NVARCHAR(18)          
            ,@d_MBOLAddDate   Datetime          
            ,@c_PlaceOfLoadingQualifier NVARCHAR(10)          
          
   SET @n_Expected = 0          
       
    -- (ChewKP03)    
   DECLARE @t_UnScanTote TABLE (                   
          Expected      INT,     
          Totes         INT,    
          MBOLKEY       NVARCHAR(10),    
          AddDate       DATETIME,    
          AddWho        NVARCHAR(18),    
          POLQ          NVARCHAR(10),    
          DropID        NVARCHAR(18),    
          Consigneekey  NVARCHAR(15),    
          ExternOrderkey NVARCHAR(50),      --tlting_ext
          OrderLineNo    NVARCHAR(5),    
          SKU           NVARCHAR(20),    
          Qty           INT,    
          UserName      NVARCHAR(18)    
              
       )           
    
-- (ChewKP03)             
--   SELECT @n_Expected = COUNT(DISTINCT PAI.RefNo)           
--   FROM   PACKINFO PAI WITH (NOLOCK)          
--   JOIN   PACKHEADER PH WITH (NOLOCK) ON (PAI.PickSlipNo = PH.PickSlipNo)          
--   JOIN   ORDERS OH WITH (NOLOCK) ON (PH.OrderKey = OH.OrderKey)    
--   JOIN   MBOL   MB WITH (NOLOCK) ON (MB.Orderkey = OH.Orderkey)    
--   WHERE  OH.OrderGroup = @c_OrderGroup          
--      AND RTRIM(ISNULL(OH.UserDefine01,'')) <> ''          
--      AND RTRIM(ISNULL(PAI.RefNo,'')) <> ''      
--      --AND OH.Status NOT IN ('9','CANC')   -- (ChewKP02)           
--          
--   SELECT TOP 1    
--          @c_MBOLKey     = M.MBOLKey,           
--          @d_MBOLAddDate = M.AddDate,           
--          @c_MBOLAddWho  = M.AddWho,           
--     @c_PlaceOfLoadingQualifier = M.PlaceOfLoadingQualifier            
--   FROM   MBOL M WITH (NOLOCK)          
--   JOIN   MBOLDetail MD WITH (NOLOCK) ON M.MBOLKey = MD.MBOLKey          
--   JOIN   ORDERS OH WITH (NOLOCK) ON (MD.OrderKey = OH.OrderKey)          
--   WHERE  OH.OrderGroup = @c_OrderGroup          
--      AND RTRIM(ISNULL(OH.UserDefine01,'')) <> ''     
      --AND OH.Status NOT IN ('9','CANC')   -- (ChewKP02)           
--   SELECT COUNT(DISTINCT PAI.RefNo)  , OH.MBOLKEY             
--          ,MB.AddDate    
--          ,MB.AddWho           
--          ,MB.PlaceOfLoadingQualifier            
--      
--   FROM   PACKINFO PAI WITH (NOLOCK)          
--   JOIN   PACKHEADER PH WITH (NOLOCK) ON (PAI.PickSlipNo = PH.PickSlipNo)          
--   JOIN   ORDERS OH WITH (NOLOCK) ON (PH.OrderKey = OH.OrderKey)     
--   JOIN   MBOL MB WITH (NOLOCK) ON (MB.MBOLKEY = OH.MBOLKEY)    
--   JOIN   MBOLDETAIL MD WITH (NOLOCK) ON (MD.Orderkey = OH.Orderkey)    
--   WHERE  OH.OrderGroup = '800910'          
--      AND RTRIM(ISNULL(OH.UserDefine01,'')) <> ''          
--      AND RTRIM(ISNULL(PAI.RefNo,'')) <> ''      
--   GROUP By OH.MBOLKEY             
--          ,MB.AddDate    
--          ,MB.AddWho           
--          ,MB.PlaceOfLoadingQualifier      
       
       
              
   DECLARE CursorMBOL CURSOR LOCAL FAST_FORWARD READ_ONLY FOR      
   SELECT COUNT(DISTINCT PAI.RefNo)     
          , OH.MBOLKEY             
          ,MB.AddDate    
          ,MB.AddWho           
          ,MB.PlaceOfLoadingQualifier            
   FROM   PACKINFO PAI WITH (NOLOCK)          
   JOIN   PACKHEADER PH WITH (NOLOCK) ON (PAI.PickSlipNo = PH.PickSlipNo)          
   JOIN   ORDERS OH WITH (NOLOCK) ON (PH.OrderKey = OH.OrderKey)     
   JOIN   MBOL MB WITH (NOLOCK) ON (MB.MBOLKEY = OH.MBOLKEY)    
   JOIN   MBOLDETAIL MD WITH (NOLOCK) ON (MD.Orderkey = OH.Orderkey)    
   WHERE  OH.OrderGroup = @c_OrderGroup     
      AND RTRIM(ISNULL(OH.UserDefine01,'')) <> ''          
      AND RTRIM(ISNULL(PAI.RefNo,'')) <> ''      
   GROUP By OH.MBOLKEY             
          ,MB.AddDate    
          ,MB.AddWho           
          ,MB.PlaceOfLoadingQualifier     
              
   OPEN CursorMBOL            
   FETCH NEXT FROM CursorMBOL INTO  @n_Expected,  @c_MBOLKey, @d_MBOLAddDate,  @c_MBOLAddWho,  @c_PlaceOfLoadingQualifier       
                    
   WHILE @@FETCH_STATUS <> -1            
   BEGIN    
          
      SELECT @n_Totes = COUNT(DISTINCT STT.RefNo)           
      FROM   RDT.RDTScanToTruck STT WITH (NOLOCK) 
      INNER JOIN ORDERS O WITH (NOLOCK) ON O.Orderkey = STT.URNNo   -- (ChewKP04) 
      WHERE  STT.MBOLKey = @c_MBOLKey                               -- (ChewKP04) 
      AND    O.Ordergroup =  @c_OrderGroup  
          
            
      INSERT INTO @t_UnScanTote      
      SELECT   @n_Expected,   @n_Totes,             
               @c_MBOLKey,    @d_MBOLAddDate,          
               @c_MBOLAddWho, @c_PlaceOfLoadingQualifier,           
               PAI.RefNo,     OH.ConsigneeKey,           
               OH.ExternOrderKey,   OD.OrderLineNumber,           
               OD.SKU,        OD.QtyAllocated + OD.QtyPicked AS Qty, suser_sname()          
      FROM PACKINFO PAI WITH (NOLOCK)          
      JOIN PACKHEADER PH WITH (NOLOCK) ON (PAI.PickSlipNo = PH.PickSlipNo)          
      JOIN ORDERS OH WITH (NOLOCK) ON (PH.OrderKey = OH.OrderKey)          
      JOIN ORDERDETAIL OD WITH (NOLOCK) ON (OH.OrderKey = OD.OrderKey)     
      JOIN MBOL MB WITH (NOLOCK) ON (MB.MBOLKEY = OH.MBOLKEY)    
      JOIN MBOLDETAIL MD WITH (NOLOCK) ON (MD.Orderkey = OH.Orderkey)              
      WHERE OH.OrderGroup = @c_OrderGroup          
         AND RTRIM(ISNULL(OH.UserDefine01,'')) <> ''          
         AND NOT EXISTS (SELECT 1 FROM RDT.RDTScanToTruck STT WITH (NOLOCK) WHERE PAI.REFNO = STT.REFNO AND MBOLKEY = @c_MBOLKey)-- AND MD.MBOLKey = STT.MBOLKey)          
         AND RTRIM(ISNULL(OH.UserDefine01,''))  <> '' -- (ChewKP01)      
         --AND OH.Status NOT IN ('9','CANC')   -- (ChewKP02)      
         AND MB.MBOLKEY = @c_MBOLKey    
        
  
        
      -- Insert Header Record if Records blank  
      IF @@RowCount = 0  
      BEGIN  
           INSERT INTO @t_UnScanTote (Expected, Totes, MbolKey, AddDate, AddWho, POLQ)  
           VALUES (@n_Expected, @n_Totes, @c_MBOLKey, @d_MBOLAddDate, @c_MBOLAddWho, @c_PlaceOfLoadingQualifier)  
      END  
          
      FETCH NEXT FROM CursorMBOL INTO  @n_Expected,  @c_MBOLKey, @d_MBOLAddDate,  @c_MBOLAddWho,  @c_PlaceOfLoadingQualifier       
   END         
   CLOSE CursorMBOL            
   DEALLOCATE CursorMBOL       
    
   SELECT * FROM @t_UnScanTote    
                  
       
          
       
END -- procedure

GO