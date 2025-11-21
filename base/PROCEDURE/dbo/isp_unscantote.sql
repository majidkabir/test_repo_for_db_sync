SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/        
/* Stored Procedure: isp_UnscanTote                                     */        
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
/* 03-09-2010   James  1.1 Cater for Store Orders only (james01)        */     
/* 07-09-2010   ChewKP 1.2 Change Logic of searching UnScan Tote        */  
/*                         (ChewKP01)                                   */ 
/* 14-09-2010   ChewKP 1.3 Bug Fixes : Exclude Shipped Tote (ChewKP02)  */ 
/* 15-09-2010   ChewKP 1.4 Add Count for Picked but Not Pack Tote       */
/*                         (ChewKP03)                                   */ 
-- /* 25-09-2012   Leong  1.5 SOS# 254822 - Eliminate duplicate records.   */
/* 28-Jan-2019  TLTING_ext 1.6  enlarge externorderkey field length      */
/************************************************************************/        
CREATE PROC [dbo].[isp_UnscanTote]     
(    
   @c_MBOLKey   NVARCHAR(10)    
)        
AS        
BEGIN    
   SET NOCOUNT ON 
   SET ANSI_NULLS OFF 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF  
        
   DECLARE  @c_Route      NVARCHAR(10)    
            ,@n_Expected   INT    
            ,@n_Totes      INT    
            ,@d_AddDate   DateTime -- (ChewKP01)  
            ,@c_AddWho    NVARCHAR(18)  
            ,@c_PlaceOfLoadingQualifier NVARCHAR(10)  
            ,@n_UnPackTote INT
        
   SET @n_Expected = 0    
   SET @c_AddWho = ''  
   SET @c_PlaceOfLoadingQualifier = ''
   SET @n_UnPackTote   = 0 
       
--    CartonType = 'STORE'    
   SELECT @n_Expected = COUNT(DISTINCT PD.DROPID)     
   FROM PACKDETAIL PD WITH (NOLOCK)    
   JOIN PACKHEADER PH WITH (NOLOCK)     
                      ON (PD.PickSlipNo = PH.PickSlipNo)    
   JOIN MBOLDETAIL MD WITH (NOLOCK)    
                      ON (PH.OrderKey = MD.OrderKey)    
   JOIN ORDERDETAIL OD WITH (NOLOCK)     
                      ON (MD.OrderKey = OD.OrderKey     
   AND RTRIM(ISNULL(OD.UserDefine01,'')) = '')    
   JOIN ORDERS OH WITH (NOLOCK) ON OH.Orderkey = OD.Orderkey
   WHERE MD.MBOLKey = @c_MBOLKey    
   AND RTRIM(ISNULL(PD.DROPID,'')) <> ''    
   AND OH.Status NOT IN ('9','CANC')   -- (ChewKP02)  
   
   -- (ChewKP03)
   DECLARE @t_PickTote TABLE (               
          DropID            NVARCHAR(18)
       )  
       
     -- (ChewKP03)
   DECLARE @t_UnPackTote TABLE (               
          DropID            NVARCHAR(18)
       )                
   
   -- (ChewKP03)
   INSERT INTO @t_PickTote    
   SELECT Distinct PD.DropID FROM dbo.PickDetail PD(NOLOCK)
   INNER JOIN TaskDetail TD WITH (NOLOCK) ON TD.TaskDetailKey = PD.TaskDetailKey
   INNER JOIN ORDERS OH WITH (NOLOCK) ON OH.Orderkey = PD.Orderkey
   INNER JOIN MBOLDETAIL MD WITH (NOLOCK) ON OH.MbolKey = MD.MbolKey
   WHERE MD.MBOLKey = @c_MBOLKey    
   AND TD.PickMethod = 'PIECE'
   
   
   INSERT INTO @t_UnPackTote
   SELECT DropID FROM @t_PickTote 
   WHERE DropID NOT IN ( SELECT STT.RefNo    
   FROM RDT.RDTScanToTruck STT WITH (NOLOCK)    
   WHERE STT.MBOLKey = @c_MBOLKey    
   AND RTRIM(ISNULL(STT.RefNo,'')) <> ''  )
   
   -- (ChewKP03)
   SELECT @n_UnPackTote = COUNT(DropID) FROM @t_PickTote 
   WHERE DropID NOT IN ( SELECT STT.RefNo    
   FROM RDT.RDTScanToTruck STT WITH (NOLOCK)    
   WHERE STT.MBOLKey = @c_MBOLKey    
   AND RTRIM(ISNULL(STT.RefNo,'')) <> ''  )
   
        
   SELECT @n_Totes = COUNT(DISTINCT STT.RefNo)     
   FROM RDT.RDTScanToTruck STT WITH (NOLOCK)    
   WHERE STT.MBOLKey = @c_MBOLKey    
   AND RTRIM(ISNULL(STT.RefNo,'')) <> ''  
   
   
   -- (ChewKP03)
   SET @n_Expected = @n_Expected + @n_UnPackTote
   SET @n_Totes = @n_Totes --+  @n_UnPackTote

          
     
     
--   SELECT   @n_Expected,   @n_Totes,       
--            MBOL.MBOLKey,  MBOL.AddDate,    
--            MBOL.AddWho,   MBOL.PlaceOfLoadingQualifier,     
--            PD.DROPID,      OH.ConsigneeKey,     
--            OH.ExternOrderKey,   OD.OrderLineNumber,     
--            PD.SKU,        PD.Qty, suser_sname()    
--   FROM PACKDETAIL PD WITH (NOLOCK)    
--   JOIN PACKHEADER PH WITH (NOLOCK)     
--                      ON (PD.PickSlipNo = PH.PickSlipNo)    
--   JOIN MBOLDETAIL MD WITH (NOLOCK)    
--                      ON (PH.OrderKey = MD.OrderKey)    
--   JOIN MBOL MBOL WITH (NOLOCK)    
--                      ON (MD.MBOLKey = MBOL.MBOLKey)    
--   JOIN ORDERDETAIL OD WITH (NOLOCK)  
--                      ON (PH.OrderKey = OD.OrderKey       
--                      AND PD.SKU = OD.SKU)    
--   JOIN ORDERS OH WITH (NOLOCK)  
--                    ON (OD.OrderKey = OH.OrderKey    
--                    AND RTRIM(ISNULL(OH.UserDefine01,'')) = '')    
--   JOIN STORERSODEFAULT WITH (NOLOCK)  
--                    ON O.ConsigneeKey = SOD.StorerKey    
----   LEFT JOIN RDT.RDTScanToTruck STT WITH (NOLOCK)    
----   ON (MD.MBOLKey = STT.MBOLKey    
----   AND PD.DROPID = STT.RefNo)    
--   WHERE MD.MBOLKey = @c_MBOLKey    
--   AND RTRIM(ISNULL(PD.DROPID,'')) <> ''    
----   AND RTRIM(ISNULL(STT.RefNo,'')) = ''    
--   AND NOT EXISTS (SELECT 1 FROM RDT.RDTSCANTOTRUCK STT WITH (NOLOCK)     
--                   WHERE STT.MBOLKEY = MD.MBOLKEY AND PD.DROPID = STT.REFNO)      
                     
   -- (ChewKP01) Start  
   SELECT @d_AddDate = AddDate,  
          @c_AddWho  = AddWho,  
          @c_PlaceOfLoadingQualifier = PlaceOfLoadingQualifier  
   FROM MBOL WITH (NOLOCK)  
   WHERE MBOLKEy = @c_MBOLKey  
   
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
          ExternOrderkey NVARCHAR(30),   --tlting_ext
          OrderLineNo    NVARCHAR(5),
          SKU           NVARCHAR(20),
          Qty           INT,
          UserName      NVARCHAR(18)
          
       )       
   
   INSERT INTO @t_UnScanTote  
   SELECT   @n_Expected,    @n_Totes,       
            @c_MBOLKey,     @d_AddDate,    
            @c_AddWho,      @c_PlaceOfLoadingQualifier,     
            PD.DROPID,      OH.ConsigneeKey,     
            OH.ExternOrderKey,   OD.OrderLineNumber,     
            PD.SKU,        PD.Qty, suser_sname()    
   FROM PACKDETAIL PD WITH (NOLOCK)    
   JOIN PACKHEADER PH WITH (NOLOCK)     
                      ON (PD.PickSlipNo = PH.PickSlipNo)    
   JOIN ORDERDETAIL OD WITH (NOLOCK)  
                      ON (PH.OrderKey = OD.OrderKey       
                      AND PD.SKU = OD.SKU)    
   JOIN ORDERS OH WITH (NOLOCK)  
                    ON (OD.OrderKey = OH.OrderKey    
                    AND RTRIM(ISNULL(OH.UserDefine01,'')) = '')    
   JOIN STORERSODEFAULT SOD WITH (NOLOCK)  
                    ON OH.ConsigneeKey = SOD.StorerKey    
   AND RTRIM(ISNULL(PD.DROPID,'')) <> ''   
   WHERE SOD.Route = @c_PlaceOfLoadingQualifier  
   AND NOT EXISTS (SELECT 1 FROM RDT.RDTSCANTOTRUCK STT WITH (NOLOCK)     
                   WHERE STT.MBOLKEY =  @c_MBOLKey  AND PD.DROPID = STT.REFNO  )    
   AND RTRIM(ISNULL(OH.UserDefine01,''))  = ''  
   AND OH.Status NOT IN ('9','CANC')   -- (ChewKP02)                
   -- (ChewKP01) End  
   
   -- (ChewKP03)
   -- SELECT PICK But Not PackItems
   INSERT INTO @t_UnScanTote  
   SELECT DISTINCT  @n_Expected,    @n_Totes,       
            @c_MBOLKey,     @d_AddDate,    
            @c_AddWho,      @c_PlaceOfLoadingQualifier,     
            PD.DROPID,      OH.ConsigneeKey,     
            OH.ExternOrderKey,   PD.OrderLineNumber,  
            PD.SKU,        PD.Qty, suser_sname()  
   FROM PICKDETAIL PD WITH (NOLOCK)
   JOIN ORDERS OH WITH (NOLOCK) ON OH.Orderkey = PD.Orderkey
   JOIN ORDERDetail OD WITH (NOLOCK) ON OD.Orderkey = OH.Orderkey
   JOIN STORERSODEFAULT SOD WITH (NOLOCK)  
                    ON OH.ConsigneeKey = SOD.StorerKey    
                    AND RTRIM(ISNULL(PD.DROPID,'')) <> ''   
   JOIN MBOLDETAIL MB WITH (NOLOCK) ON MB.Orderkey = OH.Orderkey
   WHERE SOD.Route = @c_PlaceOfLoadingQualifier 
   AND PD.DropID IN (SELECT DropID FROM @t_UnPackTote )
   AND RTRIM(ISNULL(OH.UserDefine01,''))  = ''  
   AND MB.MBOLKEY = @c_MBOLKey
   AND OH.Status NOT IN ('9','CANC') 
   
   
   SELECT DISTINCT * FROM @t_UnScanTote -- SOS# 254822
   
     
END -- procedure

GO