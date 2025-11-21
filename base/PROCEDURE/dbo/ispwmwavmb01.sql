SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/                                                                                  
/* Store Procedure: ispWMWAVMB01                                        */                                                                                  
/* Creation Date: 21-MAR-2023                                           */                                                                                  
/* Copyright: LFL                                                       */                                                                                  
/* Written by:                                                          */                                                                                  
/*                                                                      */                                                                                  
/* Purpose: WMS-22042 THA Adidas wave generate mbol                     */           
/*          (modified from WM.lsp_Wave_BuildMBOL)                       */                                                                       
/*                                                                      */                                                                                  
/* Called By: SCE lan using SCE STD Build Load param setup              */                                                                                   
/*          : isp_WaveGenMBOL_Wrapper                                   */             
/*          : Storerconfig - WAVEGENMBOL_SP                             */                                        
/* PVCS Version: 1.0                                                    */                                                                                  
/*                                                                      */                                                                                  
/* Version: 7.0                                                         */                                                                                  
/*                                                                      */                                                                                  
/* Data Modifications:                                                  */                                                                                  
/*                                                                      */                                                                                  
/* Updates:                                                             */                                                                                  
/* Date        Author   Ver.  Purposes                                  */ 
/* 21-MAR-2023 NJOW     1.0   DEVOPS Combine Script                     */
/************************************************************************/                                                                                  
CREATE   PROC [dbo].[ispWMWAVMB01]                                                                                                                   
   @c_WaveKey NVARCHAR(10),  
   @b_Success INT OUTPUT,   
   @n_err     INT OUTPUT,   
   @c_errmsg  NVARCHAR(250) OUTPUT,
   @b_debug   INT = 0                                                                                                                              
AS                                                                                                                                                          
   SET NOCOUNT ON                                                                                                                                           
   SET ANSI_NULLS OFF                                                                                                                                       
   SET QUOTED_IDENTIFIER OFF                                                                                                                                
   SET CONCAT_NULL_YIELDS_NULL OFF                                                                                                                          
   
   DECLARE @n_Continue                 BIT            = 1
         , @n_StartTCnt                INT            = @@TRANCOUNT  
                                                                                                                                                                                                                                                                                                 
   DECLARE @d_StartBatchTime           DATETIME       = GETDATE() 
         , @d_StartTime                DATETIME       = GETDATE()                                                                                                                  
         , @d_EndTime                  DATETIME                                                                                                                        
         , @d_StartTime_Debug          DATETIME       = GETDATE()                                                                                                                     
         , @d_EndTime_Debug            DATETIME                                                                                                                        
         , @d_EditDate                 DATETIME        
         
         , @c_BuildKeyFacility         NVARCHAR(5)    = ''
         , @c_BuildKeyStorerkey        NVARCHAR(10)   = ''                                                                                                                
             
         , @n_cnt                      INT            = 0 
         , @n_BuildGroupCnt            INT            = 0                 
         , @n_idx                      INT            = 0    
                                                                                    
         , @n_MaxMBOLOrders            INT            = 0                                                                                                               
         , @n_MaxOpenQty               INT            = 0
         , @n_MaxMBOL                  INT            = 0

         , @c_Restriction              NVARCHAR(30) = '' 
         , @c_Restriction01            NVARCHAR(30) = ''      
         , @c_Restriction02            NVARCHAR(30) = ''
         , @c_Restriction03            NVARCHAR(30) = ''
         , @c_Restriction04            NVARCHAR(30) = ''
         , @c_Restriction05            NVARCHAR(30) = ''
         , @c_RestrictionValue         NVARCHAR(10) = ''
         , @c_RestrictionValue01       NVARCHAR(10) = ''
         , @c_RestrictionValue02       NVARCHAR(10) = ''
         , @c_RestrictionValue03       NVARCHAR(10) = ''
         , @c_RestrictionValue04       NVARCHAR(10) = '' 
         , @c_RestrictionValue05       NVARCHAR(10) = ''
                                                  
         , @c_BuildParmKey             NVARCHAR(10)   = ''
         , @c_ParmBuildType            NVARCHAR(10)   = ''
         , @c_FieldName                NVARCHAR(100)  = ''                                                                                                                     
         , @c_Operator                 NVARCHAR(60)   = ''

         , @c_TableName                NVARCHAR(30)   = ''                                                                                                                
         , @c_ColName                  NVARCHAR(100)  = ''                                                                                                                 
         , @c_ColType                  NVARCHAR(128)  = ''
         , @c_BuildTypeValue           NVARCHAR(4000) = ''              
         , @b_ValidTable               INT            = 0               
         , @b_ValidColumn              INT            = 0                       

         , @b_GroupFlag                BIT            = 0          
         , @c_SortBy                   NVARCHAR(2000) = ''                                                                                                                
         , @c_SortSeq                  NVARCHAR(10)   = ''  
         , @c_GroupBySortField         NVARCHAR(2000) = ''                                                                                                                      
                                                                                                            
         , @c_Field01                  NVARCHAR(60)   = ''                                                                                                                  
         , @c_Field02                  NVARCHAR(60)   = ''                                                                                                                  
         , @c_Field03                  NVARCHAR(60)   = ''                                                                                                                  
         , @c_Field04                  NVARCHAR(60)   = ''                                                                                                                  
         , @c_Field05                  NVARCHAR(60)   = ''                                                                                                                  
         , @c_Field06                  NVARCHAR(60)   = ''                                                                                                                  
         , @c_Field07                  NVARCHAR(60)   = ''                                                                                                                  
         , @c_Field08                  NVARCHAR(60)   = ''                                                                                                                  
         , @c_Field09                  NVARCHAR(60)   = '' 
         , @c_Field10                  NVARCHAR(60)   = ''  
         , @c_SQLField                 NVARCHAR(2000) = ''
         , @c_SQLFieldGroupBy          NVARCHAR(2000) = ''                 
         , @c_SQLBuildByGroup          NVARCHAR(4000) = ''
         , @c_SQLBuildByGroupWhere     NVARCHAR(4000) = ''  
                                                                                                                         
         , @c_SQL                      NVARCHAR(MAX)  = ''
         , @c_SQLParms                 NVARCHAR(2000) = ''
         , @c_SQLWhere                 NVARCHAR(2000) = ''  
         , @c_SQLGroupBy               NVARCHAR(2000) = ''  

         , @n_Num                      INT            = 0
              
         , @n_OrderCnt                 INT            = 0
         , @n_MBOLCnt                  INT            = 0
         , @n_MaxOrders                INT            = 0
         , @n_OpenQty                  INT            = 0
         , @n_TotalOrders              INT            = 0                                                                                                                 
         , @n_TotalOpenQty             INT            = 0
         , @n_TotalOrderCnt            INT            = 0
         , @n_Weight                   FLOAT          = 0.00
         , @n_Cube                     FLOAT          = 0.00
         , @n_TotalWeight              FLOAT          = 0.00
         , @n_TotalCube                FLOAT          = 0.00

         , @c_BUILDMBOLKey             NVARCHAR(10)   = ''
         , @c_MBOLkey                  NVARCHAR(10)   = ''  
         , @c_Loadkey                  NVARCHAR(10)   = ''
         , @c_Orderkey                 NVARCHAR(10)   = '' 
         , @c_ExternOrderkey           NVARCHAR(50)   = ''	
         , @c_Route                    NVARCHAR(10)   = ''
         , @d_OrderDate                DATETIME       = NULL
         , @d_DeliveryDate             DATETIME       = NULL
         , @c_Facility                 NVARCHAR(5)    = ''                                                                                                                 
         , @c_StorerKey                NVARCHAR(15)   = ''         
         
   DECLARE @CUR_BUILD_SORT             CURSOR
         , @CUR_BUILDMBOL              CURSOR

   SET @b_Success = 1
   SET @n_Err     = 0
      
   SELECT TOP 1 
      @c_Storerkey = ORDERS.Storerkey, 
      @c_Facility  = ORDERS.Facility  
   FROM WAVEDETAIL (NOLOCK)  
   JOIN ORDERS (NOLOCK) ON (WAVEDETAIL.Orderkey = ORDERS.Orderkey) 
   WHERE WAVEDETAIL.Wavekey = @c_WaveKey  
          
   CREATE TABLE #tWaveOrder                                                                                                                                    
   (                                           
      RNum              INT NOT NULL PRIMARY KEY                                                                  
   ,  OrderKey          NVARCHAR(10)   NULL DEFAULT ('') 
   ,  Loadkey           NVARCHAR(10)   NULL DEFAULT ('')                                                                                                                               
   ,  ExternOrderKey    NVARCHAR(50)   NULL DEFAULT ('')	                                                                                                                       
   ,  [Route]           NVARCHAR(10)   NULL DEFAULT ('')
   ,  OrderDate         DATETIME       NULL                                                                                                                         
   ,  DeliveryDate      DATETIME       NULL                                                                                                                                  
   ,  [Weight]          FLOAT          NULL DEFAULT (0.00)                                                                                                                       
   ,  [Cube]            FLOAT          NULL DEFAULT (0.00)                                                                                                                           
   ,  AddWho            NVARCHAR(128)  NULL DEFAULT ('')                                                                                                                       
   )                                                                      
   
   IF @n_continue IN(1,2)  --Populate temp order table
   BEGIN
      CREATE TABLE #tOrders (
      	[OrderKey] [nvarchar](10) NOT NULL PRIMARY KEY,
      	[StorerKey] [nvarchar](15) NOT NULL,
      	[ExternOrderKey] [nvarchar](50) NOT NULL,
      	[OrderDate] [datetime] NOT NULL,
      	[DeliveryDate] [datetime] NOT NULL,
      	[Priority] [nvarchar](10) NOT NULL,
      	[ConsigneeKey] [nvarchar](15) NOT NULL,
      	[C_contact1] [nvarchar](100) NULL,
      	[C_Contact2] [nvarchar](100) NULL,
      	[C_Company] [nvarchar](100) NULL,
      	[C_Address1] [nvarchar](45) NULL,
      	[C_Address2] [nvarchar](45) NULL,
      	[C_Address3] [nvarchar](45) NULL,
      	[C_Address4] [nvarchar](45) NULL,
      	[C_City] [nvarchar](45) NULL,
      	[C_State] [nvarchar](45) NULL,
      	[C_Zip] [nvarchar](18) NULL,
      	[C_Country] [nvarchar](30) NULL,
      	[C_ISOCntryCode] [nvarchar](10) NULL,
      	[C_Phone1] [nvarchar](18) NULL,
      	[C_Phone2] [nvarchar](18) NULL,
      	[C_Fax1] [nvarchar](18) NULL,
      	[C_Fax2] [nvarchar](18) NULL,
      	[C_vat] [nvarchar](18) NULL,
      	[BuyerPO] [nvarchar](20) NULL,
      	[BillToKey] [nvarchar](15) NOT NULL,
      	[B_contact1] [nvarchar](100) NULL,
      	[B_Contact2] [nvarchar](100) NULL,
      	[B_Company] [nvarchar](100) NULL,
      	[B_Address1] [nvarchar](45) NULL,
      	[B_Address2] [nvarchar](45) NULL,
      	[B_Address3] [nvarchar](45) NULL,
      	[B_Address4] [nvarchar](45) NULL,
      	[B_City] [nvarchar](45) NULL,
      	[B_State] [nvarchar](45) NULL,
      	[B_Zip] [nvarchar](18) NULL,
      	[B_Country] [nvarchar](30) NULL,
      	[B_ISOCntryCode] [nvarchar](10) NULL,
      	[B_Phone1] [nvarchar](18) NULL,
      	[B_Phone2] [nvarchar](18) NULL,
      	[B_Fax1] [nvarchar](18) NULL,
      	[B_Fax2] [nvarchar](18) NULL,
      	[B_Vat] [nvarchar](18) NULL,
      	[IncoTerm] [nvarchar](10) NULL,
      	[PmtTerm] [nvarchar](10) NULL,
      	[OpenQty] [int] NULL,
      	[Status] [nvarchar](10) NOT NULL,
      	[DischargePlace] [nvarchar](30) NULL,
      	[DeliveryPlace] [nvarchar](30) NULL,
      	[IntermodalVehicle] [nvarchar](30) NOT NULL,
      	[CountryOfOrigin] [nvarchar](30) NULL,
      	[CountryDestination] [nvarchar](30) NULL,
      	[UpdateSource] [nvarchar](10) NOT NULL,
      	[Type] [nvarchar](10) NOT NULL,
      	[OrderGroup] [nvarchar](20) NOT NULL,
      	[Door] [nvarchar](10) NOT NULL,
      	[Route] [nvarchar](10) NOT NULL,
      	[Stop] [nvarchar](10) NOT NULL,
      	[Notes] [nvarchar](4000) NULL,
      	[EffectiveDate] [datetime] NOT NULL,
      	[AddDate] [datetime] NOT NULL,
      	[AddWho] [nvarchar](128) NOT NULL,
      	[EditDate] [datetime] NOT NULL,
      	[EditWho] [nvarchar](128) NOT NULL,
      	[TrafficCop] [nvarchar](1) NULL,
      	[ArchiveCop] [nvarchar](1) NULL,
      	[ContainerType] [nvarchar](20) NULL,
      	[ContainerQty] [int] NULL,
      	[BilledContainerQty] [int] NULL,
      	[SOStatus] [nvarchar](10) NULL,
      	[MBOLKey] [nvarchar](10) NULL,
      	[InvoiceNo] [nvarchar](20) NULL,
      	[InvoiceAmount] [float] NULL,
      	[Salesman] [nvarchar](30) NULL,
      	[GrossWeight] [float] NULL,
      	[Capacity] [float] NULL,
      	[PrintFlag] [nvarchar](1) NULL,
      	[LoadKey] [nvarchar](10) NULL,
      	[Rdd] [nvarchar](30) NULL,
      	[Notes2] [nvarchar](4000) NULL,
      	[SequenceNo] [int] NULL,
      	[Rds] [nvarchar](1) NULL,
      	[SectionKey] [nvarchar](10) NULL,
      	[Facility] [nvarchar](5) NULL,
      	[PrintDocDate] [datetime] NULL,
      	[LabelPrice] [nvarchar](20) NULL,
      	[POKey] [nvarchar](10) NULL,
      	[ExternPOKey] [nvarchar](20) NULL,
      	[XDockFlag] [nvarchar](1) NOT NULL,
      	[UserDefine01] [nvarchar](20) NULL,
      	[UserDefine02] [nvarchar](20) NULL,
      	[UserDefine03] [nvarchar](20) NULL,
      	[UserDefine04] [nvarchar](40) NULL,
      	[UserDefine05] [nvarchar](20) NULL,
      	[UserDefine06] [datetime] NULL,
      	[UserDefine07] [datetime] NULL,
      	[UserDefine08] [nvarchar](10) NULL,
      	[UserDefine09] [nvarchar](10) NULL,
      	[UserDefine10] [nvarchar](10) NULL,
      	[Issued] [nvarchar](1) NULL,
      	[DeliveryNote] [nvarchar](10) NULL,
      	[PODCust] [datetime] NULL,
      	[PODArrive] [datetime] NULL,
      	[PODReject] [datetime] NULL,
      	[PODUser] [nvarchar](18) NULL,
      	[xdockpokey] [nvarchar](20) NULL,
      	[SpecialHandling] [nvarchar](1) NULL,
      	[RoutingTool] [nvarchar](30) NULL,
      	[MarkforKey] [nvarchar](15) NOT NULL,
      	[M_Contact1] [nvarchar](100) NULL,
      	[M_Contact2] [nvarchar](100) NULL,
      	[M_Company] [nvarchar](100) NULL,
      	[M_Address1] [nvarchar](45) NULL,
      	[M_Address2] [nvarchar](45) NULL,
      	[M_Address3] [nvarchar](45) NULL,
      	[M_Address4] [nvarchar](45) NULL,
      	[M_City] [nvarchar](45) NULL,
      	[M_State] [nvarchar](45) NULL,
      	[M_Zip] [nvarchar](18) NULL,
      	[M_Country] [nvarchar](30) NULL,
      	[M_ISOCntryCode] [nvarchar](10) NULL,
      	[M_Phone1] [nvarchar](18) NULL,
      	[M_Phone2] [nvarchar](18) NULL,
      	[M_Fax1] [nvarchar](18) NULL,
      	[M_Fax2] [nvarchar](18) NULL,
      	[M_vat] [nvarchar](18) NULL,
      	[ShipperKey] [nvarchar](15) NULL,
      	[DocType] [nvarchar](1) NULL,
      	[TrackingNo] [nvarchar](40) NULL,
      	[ECOM_PRESALE_FLAG] [nvarchar](2) NULL,
      	[ECOM_SINGLE_Flag] [nchar](1) NULL,
      	[CurrencyCode] [nvarchar](20) NULL,
      	[RTNTrackingNo] [nvarchar](40) NULL,
      	[HashValue] [tinyint] NULL,
      	[BizUnit] [nvarchar](50) NOT NULL,
      	[ECOM_OAID] [nvarchar](128) NULL,
      	[ECOM_Platform] [nvarchar](30) NULL)           
      
       INSERT INTO #tORDERS
                  ([OrderKey]
                  ,[StorerKey]
                  ,[ExternOrderKey]
                  ,[OrderDate]
                  ,[DeliveryDate]
                  ,[Priority]
                  ,[ConsigneeKey]
                  ,[C_contact1]
                  ,[C_Contact2]
                  ,[C_Company]
                  ,[C_Address1]
                  ,[C_Address2]
                  ,[C_Address3]
                  ,[C_Address4]
                  ,[C_City]
                  ,[C_State]
                  ,[C_Zip]
                  ,[C_Country]
                  ,[C_ISOCntryCode]
                  ,[C_Phone1]
                  ,[C_Phone2]
                  ,[C_Fax1]
                  ,[C_Fax2]
                  ,[C_vat]
                  ,[BuyerPO]
                  ,[BillToKey]
                  ,[B_contact1]
                  ,[B_Contact2]
                  ,[B_Company]
                  ,[B_Address1]
                  ,[B_Address2]
                  ,[B_Address3]
                  ,[B_Address4]
                  ,[B_City]
                  ,[B_State]
                  ,[B_Zip]
                  ,[B_Country]
                  ,[B_ISOCntryCode]
                  ,[B_Phone1]
                  ,[B_Phone2]
                  ,[B_Fax1]
                  ,[B_Fax2]
                  ,[B_Vat]
                  ,[IncoTerm]
                  ,[PmtTerm]
                  ,[OpenQty]
                  ,[Status]
                  ,[DischargePlace]
                  ,[DeliveryPlace]
                  ,[IntermodalVehicle]
                  ,[CountryOfOrigin]
                  ,[CountryDestination]
                  ,[UpdateSource]
                  ,[Type]
                  ,[OrderGroup]
                  ,[Door]
                  ,[Route]
                  ,[Stop]
                  ,[Notes]
                  ,[EffectiveDate]
                  ,[AddDate]
                  ,[AddWho]
                  ,[EditDate]
                  ,[EditWho]
                  ,[TrafficCop]
                  ,[ArchiveCop]
                  ,[ContainerType]
                  ,[ContainerQty]
                  ,[BilledContainerQty]
                  ,[SOStatus]
                  ,[MBOLKey]
                  ,[InvoiceNo]
                  ,[InvoiceAmount]
                  ,[Salesman]
                  ,[GrossWeight]
                  ,[Capacity]
                  ,[PrintFlag]
                  ,[LoadKey]
                  ,[Rdd]
                  ,[Notes2]
                  ,[SequenceNo]
                  ,[Rds]
                  ,[SectionKey]
                  ,[Facility]
                  ,[PrintDocDate]
                  ,[LabelPrice]
                  ,[POKey]
                  ,[ExternPOKey]
                  ,[XDockFlag]
                  ,[UserDefine01]
                  ,[UserDefine02]
                  ,[UserDefine03]
                  ,[UserDefine04]
                  ,[UserDefine05]
                  ,[UserDefine06]
                  ,[UserDefine07]
                  ,[UserDefine08]
                  ,[UserDefine09]
                  ,[UserDefine10]
                  ,[Issued]
                  ,[DeliveryNote]
                  ,[PODCust]
                  ,[PODArrive]
                  ,[PODReject]
                  ,[PODUser]
                  ,[xdockpokey]
                  ,[SpecialHandling]
                  ,[RoutingTool]
                  ,[MarkforKey]
                  ,[M_Contact1]
                  ,[M_Contact2]
                  ,[M_Company]
                  ,[M_Address1]
                  ,[M_Address2]
                  ,[M_Address3]
                  ,[M_Address4]
                  ,[M_City]
                  ,[M_State]
                  ,[M_Zip]
                  ,[M_Country]
                  ,[M_ISOCntryCode]
                  ,[M_Phone1]
                  ,[M_Phone2]
                  ,[M_Fax1]
                  ,[M_Fax2]
                  ,[M_vat]
                  ,[ShipperKey]
                  ,[DocType]
                  ,[TrackingNo]
                  ,[ECOM_PRESALE_FLAG]
                  ,[ECOM_SINGLE_Flag]
                  ,[CurrencyCode]
                  ,[RTNTrackingNo]
                  ,[HashValue]
                  ,[BizUnit]
                  ,[ECOM_OAID]
                  ,[ECOM_Platform])
       SELECT O.[OrderKey]
             ,O.[StorerKey]
             ,O.[ExternOrderKey]
             ,O.[OrderDate]
             ,O.[DeliveryDate]
             ,O.[Priority]
             ,O.[ConsigneeKey]
             ,O.[C_contact1]
             ,O.[C_Contact2]
             ,O.[C_Company]
             ,O.[C_Address1]
             ,O.[C_Address2]
             ,O.[C_Address3]
             ,O.[C_Address4]
             ,O.[C_City]
             ,O.[C_State]
             ,O.[C_Zip]
             ,O.[C_Country]
             ,O.[C_ISOCntryCode]
             ,O.[C_Phone1]
             ,O.[C_Phone2]
             ,O.[C_Fax1]
             ,O.[C_Fax2]
             ,O.[C_vat]
             ,O.[BuyerPO]
             ,O.[BillToKey]
             ,O.[B_contact1]
             ,O.[B_Contact2]
             ,O.[B_Company]
             ,O.[B_Address1]
             ,O.[B_Address2]
             ,O.[B_Address3]
             ,O.[B_Address4]
             ,O.[B_City]
             ,O.[B_State]
             ,O.[B_Zip]
             ,O.[B_Country]
             ,O.[B_ISOCntryCode]
             ,O.[B_Phone1]
             ,O.[B_Phone2]
             ,O.[B_Fax1]
             ,O.[B_Fax2]
             ,O.[B_Vat]
             ,O.[IncoTerm]
             ,O.[PmtTerm]
             ,O.[OpenQty]
             ,O.[Status]
             ,O.[DischargePlace]
             ,O.[DeliveryPlace]
             ,O.[IntermodalVehicle]
             ,O.[CountryOfOrigin]
             ,O.[CountryDestination]
             ,O.[UpdateSource]
             ,O.[Type]
             ,O.[OrderGroup]
             ,O.[Door]
             ,O.[Route]
             ,O.[Stop]
             ,O.[Notes]
             ,O.[EffectiveDate]
             ,O.[AddDate]
             ,O.[AddWho]
             ,O.[EditDate]
             ,O.[EditWho]
             ,O.[TrafficCop]
             ,O.[ArchiveCop]
             ,O.[ContainerType]
             ,O.[ContainerQty]
             ,O.[BilledContainerQty]
             ,O.[SOStatus]
             ,O.[MBOLKey]
             ,O.[InvoiceNo]
             ,O.[InvoiceAmount]
             ,O.[Salesman]
             ,O.[GrossWeight]
             ,O.[Capacity]
             ,O.[PrintFlag]
             ,O.[LoadKey]
             ,O.[Rdd]
             ,O.[Notes2]
             ,O.[SequenceNo]
             ,O.[Rds]
             ,O.[SectionKey]
             ,O.[Facility]
             ,O.[PrintDocDate]
             ,O.[LabelPrice]
             ,O.[POKey]
             ,O.[ExternPOKey]
             ,O.[XDockFlag]
             ,O.[UserDefine01]
             ,O.[UserDefine02]
             ,O.[UserDefine03]
             ,O.[UserDefine04]
             ,O.[UserDefine05]
             ,O.[UserDefine06]
             ,O.[UserDefine07]
             ,O.[UserDefine08]
             ,O.[UserDefine09]
             ,O.[UserDefine10]
             ,O.[Issued]
             ,O.[DeliveryNote]
             ,O.[PODCust]
             ,O.[PODArrive]
             ,O.[PODReject]
             ,O.[PODUser]
             ,O.[xdockpokey]
             ,CASE WHEN C.Code IS NOT NULL AND O.DocType = 'N' THEN 'Y' ELSE 'N' END --SpecialHandling
             --,O.[SpecialHandling]
             ,O.[RoutingTool]
             ,O.[MarkforKey]
             ,O.[M_Contact1]
             ,O.[M_Contact2]
             ,O.[M_Company]
             ,O.[M_Address1]
             ,O.[M_Address2]
             ,O.[M_Address3]
             ,O.[M_Address4]
             ,O.[M_City]
             ,O.[M_State]
             ,O.[M_Zip]
             ,O.[M_Country]
             ,O.[M_ISOCntryCode]
             ,O.[M_Phone1]
             ,O.[M_Phone2]
             ,O.[M_Fax1]
             ,O.[M_Fax2]
             ,O.[M_vat]
             ,O.[ShipperKey]
             ,O.[DocType]
             ,O.[TrackingNo]
             ,O.[ECOM_PRESALE_FLAG]
             ,O.[ECOM_SINGLE_Flag]
             ,O.[CurrencyCode]
             ,O.[RTNTrackingNo]
             ,O.[HashValue]
             ,O.[BizUnit]
             ,O.[ECOM_OAID]
             ,O.[ECOM_Platform]
      FROM WAVEDETAIL WD (NOLOCK) 
      JOIN ORDERS O (NOLOCK) ON WD.Orderkey = O.Orderkey
      OUTER APPLY (SELECT TOP 1 CL.Code 
                   FROM CODELKUP CL (NOLOCK) 
                   WHERE CL.ListName = 'ADACTIVEN' 
                   AND CL.Code = O.Consigneekey) C
      WHERE WD.Wavekey = @c_Wavekey
      ORDER BY O.Orderkey
   END
         	   	                                                                                                                                                            
   IF @b_debug = 2                                                                                                                                              
   BEGIN                                                                                                                                                       
      SET @d_StartTime_Debug = GETDATE()                                               
      PRINT 'SP-ispWMWAVMB01 DEBUG-START...'                                                                                                             
      PRINT '--1.Do Generate SQL Statement--'                                                                                                                  
   END                                                                                                                                                         
  
   SET @n_err = 0                                                                                                                                              
   SET @c_ErrMsg = ''                                                                                                                                         
   SET @b_Success = 1   
   
   SET @n_Cnt = 0
   SELECT TOP 1 @n_Cnt = 1
         ,@c_BuildKeyFacility = BPCFG.Facility
         ,@c_BuildKeyStorerkey= BPCFG.Storerkey
         ,@c_BuildParmKey     = BP.BuildParmKey
   FROM BUILDPARM BP WITH (NOLOCK)   
   JOIN BUILDPARMGROUPCFG BPCFG WITH (NOLOCK) ON BP.ParmGroup = BPCFG.ParmGroup
                                             AND BPCFG.[Type] = 'WaveBuildMBOL'
   WHERE BPCFG.Facility = @c_Facility
   AND   BPCFG.Storerkey= @c_Storerkey
   ORDER BY BP.BuildParmKey
   
   IF @n_Cnt = 0
   BEGIN
      GOTO DEFAULT_BUILD_BY_CONSIGNEE
   END

   IF @n_Cnt = 1 AND @c_BuildKeyStorerkey <> @c_Storerkey AND
      (@c_BuildKeyFacility <> '' AND (@c_BuildKeyFacility <> @c_Facility))
   BEGIN
      SET @n_Continue = 3                                                                                                                                     
      SET @n_Err     = 336051                                                                                                                                               
      SET @c_ErrMsg  = 'NSQL' + CONVERT(NVARCHAR(6), @n_Err) 
                     + ': Invalid Wave MBOL Group. Its Storer/Facility unmatch with Wave''s storer/Facility.' 
                     + ' (ispWMWAVMB01)'                                                                                            
      GOTO EXIT_SP           
   END

   ------------------------------------------------------
   -- Get Build MBOL Restriction: 
   ------------------------------------------------------

   SET @c_Operator  = ''
   SET @n_MaxMBOLOrders = 0
   SET @n_MaxOpenQty= 0

   SELECT @c_Restriction01          = BP.Restriction01
         ,@c_Restriction02          = BP.Restriction02
         ,@c_Restriction03          = BP.Restriction03
         ,@c_Restriction04          = BP.Restriction04
         ,@c_Restriction05          = BP.Restriction05
         ,@c_RestrictionValue01     = BP.RestrictionValue01
         ,@c_RestrictionValue02     = BP.RestrictionValue02
         ,@c_RestrictionValue03     = BP.RestrictionValue03
         ,@c_RestrictionValue04     = BP.RestrictionValue04
         ,@c_RestrictionValue05     = BP.RestrictionValue05
   FROM BUILDPARM BP WITH (NOLOCK)                                                                                                                                 
   WHERE BP.BuildParmKey = @c_BuildParmKey 
   
   SET @n_idx = 1
   WHILE @n_idx <= 5
   BEGIN
      SET @c_Restriction = CASE WHEN @n_idx = 1 THEN @c_Restriction01
                                WHEN @n_idx = 2 THEN @c_Restriction02
                                WHEN @n_idx = 3 THEN @c_Restriction03
                                WHEN @n_idx = 4 THEN @c_Restriction04
                                WHEN @n_idx = 5 THEN @c_Restriction05
                                END
      SET @c_RestrictionValue = CASE WHEN @n_idx = 1 THEN @c_RestrictionValue01
                                     WHEN @n_idx = 2 THEN @c_RestrictionValue02
                                     WHEN @n_idx = 3 THEN @c_RestrictionValue03
                                     WHEN @n_idx = 4 THEN @c_RestrictionValue04
                                     WHEN @n_idx = 5 THEN @c_RestrictionValue05
                                     END

      IF @c_Restriction = '1_MaxOrderPerBuild'
      BEGIN
         SET @n_MaxMBOLOrders = @c_RestrictionValue  
      END

      IF @c_Restriction = '2_MaxQtyPerBuild'
      BEGIN
         SET @n_MaxOpenQty = @c_RestrictionValue  
      END

      IF @c_Restriction = '3_MaxBuild'
      BEGIN
         SET @n_MaxMBOL = @c_RestrictionValue  
      END
 
      SET @n_idx = @n_idx + 1
   END

   --------------------------------------------------
   -- Get Build MBOL By Sorting & Grouping Condition
   --------------------------------------------------
   SET @n_BuildGroupCnt = 0                                                                                                                                                   
   SET @c_GroupBySortField = ''
   SET @c_SQLBuildByGroupWhere = ''
   SET @CUR_BUILD_SORT = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR                                                                                         
   SELECT TOP 10 
         BPD.FieldName
      ,  BPD.Operator
      ,  BPD.[Type]                 
      ,  BuildTypeValue = ISNULL(BPD.[Value],'')                                                                                                 
   FROM  BUILDPARMDETAIL BPD WITH (NOLOCK)                                                                                                                               
   WHERE BPD.BuildParmKey = @c_BuildParmKey                                                                                                                                
   AND   BPD.[Type]  IN ('SORT','GROUP')                                                                                                                             
   ORDER BY BPD.BuildParmLineNo                                                                                                                                              
                                                                                                                                                            
   OPEN @CUR_BUILD_SORT                                                                                                                                    
                                                                                                                                                            
   FETCH NEXT FROM @CUR_BUILD_SORT INTO @c_FieldName
                                       ,@c_Operator
                                       ,@c_ParmBuildType             
                                       ,@c_BuildTypeValue                                                                     
   WHILE @@FETCH_STATUS <> -1                             
   BEGIN  
      SET @c_BuildTypeValue = dbo.fnc_GetParamValueFromString('@c_CustomFieldName',@c_BuildTypeValue, '')

  
      IF @c_ParmBuildType = 'GROUP' AND @c_BuildTypeValue <> '' 
      BEGIN
         SET @c_TableName = 'ORDERS'         
         SET @c_FieldName = @c_BuildTypeValue
         SET @c_ColType = 'nvarchar'
         
         -- IF @c_BuildTypeValue is a SQL FUNCTION
         SET @c_BuildTypeValue = TRANSLATE(@c_BuildTypeValue, ',', ' ')
         SET @c_BuildTypeValue = TRANSLATE(@c_BuildTypeValue, ')', ' ')
         SET @c_BuildTypeValue = TRANSLATE(@c_BuildTypeValue, '=', ' ')
         SET @c_BuildTypeValue = STUFF(@c_BuildTypeValue, 1, CHARINDEX('(',@c_BuildTypeValue),'')
         
         --1. STC=>Split String by 1 empty space with Split column has '.'; Split_Text
         --2. VC => Split Each Split_Text's Column into Single Character IN a-z, 0-9 and . value. Gen RowID per Split_Text column, n = Character's id reference
         --3. TC => Concat character per Split_Text Column for Gen RowID = n
         --Lastly, Find If Valid Tablename and Column Name
         ;WITH STC AS 
         (  SELECT TableName = LEFT(ss.[value], CHARINDEX('.', ss.[value]) -1)
                  ,Split_Text = ss.[value]
            FROM STRING_SPLIT(@c_BuildTypeValue,' ') AS ss                    
            WHERE CHARINDEX('.',ss.[value]) > 0
         )
         , x AS 
         (
              SELECT TOP (100) n = ROW_NUMBER() OVER (ORDER BY Number) 
              FROM master.dbo.spt_values ORDER BY Number
         )
         , VC AS
         (
            SELECT Single_Char = SUBSTRING(STC.Split_Text, x.n, 1) 
                 , STC.Split_Text
                 , STC.TableName    
                 , x.n
                 , RowID = ROW_NUMBER() OVER (PARTITION BY STC.Split_Text ORDER BY STC.Split_Text)
            FROM STC 
            JOIN x ON x.n <= LEN(STC.Split_Text) 
            WHERE SUBSTRING(STC.Split_Text, x.n, 1) LIKE '[A-Z,0-9,.,_]'
         )
         , TC AS
         (
            SELECT VC.Split_Text
               , VC.TableName  
               , BuildCol = STRING_AGG(VC.Single_Char,'')
            FROM VC WHERE VC.RowiD = VC.n
            GROUP BY VC.Split_Text
                   , VC.TableName  
         )
         SELECT @b_ValidTable  = ISNULL(MIN(IIF(TC.TableName = @c_TableName, 1 , 0 )),0)
               ,@b_ValidColumn = ISNULL(MIN(IIF(c.COLUMN_NAME IS NOT NULL , 1 , 0 )),0)
         FROM TC
         LEFT OUTER JOIN INFORMATION_SCHEMA.COLUMNS c WITH (NOLOCK) ON c.TABLE_NAME = TC.TableName AND c.TABLE_NAME + '.' + c.COLUMN_NAME = TC.BuildCol 


         IF @b_ValidTable = 0 SET @c_TableName = ''
         IF @b_ValidColumn = 0 SET @c_ColType = ''
      END
      ELSE
      BEGIN   	                                                                                                                                                     
         -- Get Column Type                                                                                                                                       
         SET @c_TableName = LEFT(@c_FieldName, CHARINDEX('.', @c_FieldName) - 1)                                                                                   
         SET @c_ColName   = SUBSTRING(@c_FieldName,                                                                                                                
                         CHARINDEX('.', @c_FieldName) + 1, LEN(@c_FieldName) - CHARINDEX('.', @c_FieldName))                                                            
      END                   
                       
      IF @c_TableName NOT IN ('ORDERS')
      BEGIN
         SET @n_Continue = 3                                                                                                                                     
         SET @n_Err     = 336052                                                                                                                                               
         SET @c_ErrMsg  = 'NSQL' + CONVERT(NVARCHAR(6), @n_Err) 
                        + ': Only allow Sort/Group for ORDERS table. (ispWMWAVMB01)'                                                                                            
         GOTO EXIT_SP              
      END

      IF NOT (@c_ParmBuildType = 'GROUP' AND @c_BuildTypeValue <> '')               
      BEGIN                                                                                                                                                                      
         SET @c_ColType = ''                                                                                                                                       
         SELECT @c_ColType = DATA_TYPE                                                                                                                             
         FROM   INFORMATION_SCHEMA.COLUMNS WITH (NOLOCK)                                                                                                                       
         WHERE  TABLE_NAME = @c_TableName                                                                                                                          
         AND    COLUMN_NAME = @c_ColName                                                                                                                            
      END
                                                                                                                                                            
      IF ISNULL(RTRIM(@c_ColType), '') = ''                                                                                                                     
      BEGIN                                                          
         SET @n_Continue = 3                                                                                                                                     
         SET @n_Err     = 336053                                                                                                                                               
         SET @c_ErrMsg  = 'NSQL' + CONVERT(NVARCHAR(6), @n_Err) 
                        + ': Invalid Sort/Group Column Name: ' + @c_FieldName  
                        + '. (ispWMWAVMB01)'
                        + '|' + @c_FieldName                                                                                        
         GOTO EXIT_SP                                                                                                                                             
      END                                                                                                                                                      
                                                                                                                                                            
      IF @c_ParmBuildType = 'SORT'                                                                                                                                   
      BEGIN                                                                                                                                                    
         IF @c_Operator = 'DESC'                                                                                                                                
            SET @c_SortSeq = 'DESC'                                                                                                                             
         ELSE                                                                                                                                                  
            SET @c_SortSeq = ''                                                                                                                                 

            IF ISNULL(@c_GroupBySortField,'') = ''                                                                                                 
               SET @c_GroupBySortField = CHAR(13) + @c_FieldName                                                                                                          
            ELSE                                                                                                                                               
               SET @c_GroupBySortField = @c_GroupBySortField + CHAR(13) + ', ' +  RTRIM(@c_FieldName)                                                                    
                                                                                                                                                            
         IF ISNULL(@c_SortBy,'') = ''                                                                                                                           
            SET @c_SortBy = CHAR(13) + @c_FieldName + ' ' + RTRIM(@c_SortSeq)                                                                                               
         ELSE                                                                                                                                                  
            SET @c_SortBy = @c_SortBy + CHAR(13) + ', ' +  RTRIM(@c_FieldName) + ' ' + RTRIM(@c_SortSeq)                                                                     
      END        
                                                                                                                                                            
      IF @c_ParmBuildType = 'GROUP'                                                                                                                                  
      BEGIN 
         SET @n_BuildGroupCnt = @n_BuildGroupCnt + 1                      --Fixed counter increase for 'GROUP' only   
         IF ISNULL(RTRIM(@c_TableName), '') NOT IN('ORDERS')                                                                                                         
         BEGIN                                                                                                                                                 
            SET @n_Continue = 3 
            SET @n_Err    = 336054                                                                                                                                                
            SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(6), @n_Err) 
                          + ': Grouping Only Allow Refer To Orders Table''s Fields. Invalid Table: '+ RTRIM(@c_FieldName)
                          + '. (ispWMWAVMB01)'
                          + '|' + @c_FieldName                                                                      
            GOTO EXIT_SP                                                                                                                                          
         END                                                                                                                                                   
                                                                                                                                                            
         IF @c_ColType IN ('float', 'money', 'int', 'decimal', 'numeric', 'tinyint', 'real', 'bigint','text')                                                   
         BEGIN                                                                                                                                                 
            SET @n_Continue = 3 
            SET @n_Err     = 336055                                                                   
            SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(6), @n_Err) 
                          + ': Numeric/Text Column Type Is Not Allowed For Ship Ref. Unit Grouping: ' + RTRIM(@c_FieldName)
                          + '. (ispWMWAVMB01)'
                          + '|' + @c_FieldName                                                                        
            GOTO EXIT_SP                                                                                                                                          
         END                                                                                                                                                   
                                                                                                                                
         IF @c_ColType IN ('char', 'nvarchar', 'varchar', 'nchar') -- SWT02                                                                                                      
         BEGIN                                                                                                                                                 
            SET @c_SQLField = @c_SQLField + CHAR(13) + ',' + RTRIM(@c_FieldName)                                                                                       
            SET @c_SQLBuildByGroupWhere = @c_SQLBuildByGroupWhere 
                                 + CHAR(13) + ' AND ' + RTRIM(@c_FieldName) + '='                                                                            
                                 + CASE WHEN @n_BuildGroupCnt = 1  THEN '@c_Field01'                                                                                                      
                                        WHEN @n_BuildGroupCnt = 2  THEN '@c_Field02'                                                                                                      
                                        WHEN @n_BuildGroupCnt = 3  THEN '@c_Field03'                                                                                                      
                                        WHEN @n_BuildGroupCnt = 4  THEN '@c_Field04'                                                                                                      
                                        WHEN @n_BuildGroupCnt = 5  THEN '@c_Field05'                                                                                                      
                                        WHEN @n_BuildGroupCnt = 6  THEN '@c_Field06'                                                                                                      
                                        WHEN @n_BuildGroupCnt = 7  THEN '@c_Field07'                                                                                                      
                                        WHEN @n_BuildGroupCnt = 8  THEN '@c_Field08'                                                                                                      
                                        WHEN @n_BuildGroupCnt = 9  THEN '@c_Field09'                                                                                                      
                                        WHEN @n_BuildGroupCnt = 10 THEN '@c_Field10' END                                                                                                 
            SET @b_GroupFlag = 1                                                                                                                            
         END                                                                                                                                                   
                                                                                                                                                            
         IF @c_ColType IN ('datetime')                                                                                                                          
         BEGIN                                                                                                                                                 
            SET @c_SQLField = @c_SQLField + CHAR(13) +  ', CONVERT(NVARCHAR(10),' + RTRIM(@c_FieldName) + ',112)'                                                       
            SET @c_SQLBuildByGroupWhere = @c_SQLBuildByGroupWhere 
                                 + CHAR(13) + ' AND CONVERT(NVARCHAR(10),' + RTRIM(@c_FieldName) + ',112)='                      
                                 + CASE WHEN @n_BuildGroupCnt = 1  THEN '@c_Field01'                                                                                                      
                                        WHEN @n_BuildGroupCnt = 2  THEN '@c_Field02'                                                                                                      
                                        WHEN @n_BuildGroupCnt = 3  THEN '@c_Field03'                                                                                                      
                                        WHEN @n_BuildGroupCnt = 4  THEN '@c_Field04'                                                                   
                                        WHEN @n_BuildGroupCnt = 5  THEN '@c_Field05'                                                                                                      
                                        WHEN @n_BuildGroupCnt = 6  THEN '@c_Field06'                                                                                                      
                                        WHEN @n_BuildGroupCnt = 7  THEN '@c_Field07'                                                                                                      
                                        WHEN @n_BuildGroupCnt = 8  THEN '@c_Field08'                                                                                                      
                                        WHEN @n_BuildGroupCnt = 9  THEN '@c_Field09'                                                                                                      
                                        WHEN @n_BuildGroupCnt = 10 THEN '@c_Field10' END                                                                                                 
            SET @b_GroupFlag = 1                                                                                                                            
         END                                                                                                                                                   
      END 
                                                               
      FETCH NEXT FROM @CUR_BUILD_SORT INTO @c_FieldName
                                          ,@c_Operator
                                          ,@c_ParmBuildType      
                                          ,@c_BuildTypeValue                                                                           
   END                                                                                                                                                         
   CLOSE @CUR_BUILD_SORT                                                                                                                                   
   DEALLOCATE @CUR_BUILD_SORT  

   DEFAULT_BUILD_BY_CONSIGNEE:
   IF ISNULL(@c_SQLBuildByGroupWhere,'') = '' AND ISNULL(@c_SortBy,'') = ''
   BEGIN   
      SET @n_BuildGroupCnt = 2 
      SET @c_SQLField = ',ORDERS.Consigneekey'
           + CHAR(13) + ',ORDERS.C_Company'                                                                                                                            
      SET @c_SQLBuildByGroupWhere = @c_SQLBuildByGroupWhere
                       + CHAR(13) + 'AND ORDERS.Consigneekey = @c_Field01'
                       + CHAR(13) + 'AND ORDERS.C_Company = @c_Field02'
   END

   IF ISNULL(@c_SortBy,'') = '' 
   BEGIN                                                                                                                                
      SET @c_SortBy = 'WAVEDETAIL.WaveDetailKey'
   END
   ------------------------------------------------------
   -- Construct Build MBOL SQL
   ------------------------------------------------------ 
  
   SET @c_SQL = N'INSERT INTO #tWaveOrder(RNum,OrderKey,Loadkey,ExternOrderKey'
      + CHAR(13) + ',[Route],OrderDate,DeliveryDate'
      + CHAR(13) + ',[Weight],[Cube],AddWho)' 
      + CHAR(13) + ' SELECT ROW_NUMBER() OVER (ORDER BY ' + RTRIM(@c_SortBy) + ') AS Number'
      + CHAR(13) + ',ORDERS.OrderKey,ORDERS.Loadkey,ORDERS.ExternOrderKey'
      + CHAR(13) + ',ORDERS.[Route],ORDERS.OrderDate,ORDERS.DeliveryDate'
      + CHAR(13) + ',SUM(ORDERDETAIL.OpenQty * SKU.StdGrossWgt), SUM(ORDERDETAIL.OpenQty * SKU.StdCube)'
      + CHAR(13) + ',''*'' + RTRIM(sUser_sName())'

   SET @c_SQLWhere = N'FROM WAVEDETAIL WITH (NOLOCK) '
      + CHAR(13) + 'JOIN #tORDERS ORDERS WITH (NOLOCK) ON WAVEDETAIL.OrderKey = ORDERS.OrderKey'  
      + CHAR(13) + 'JOIN ORDERDETAIL WITH (NOLOCK) ON ORDERS.OrderKey = ORDERDETAIL.OrderKey'  
      + CHAR(13) + 'JOIN SKU WITH (NOLOCK) ON ORDERDETAIL.Storerkey = SKU.Storerkey AND ORDERDETAIL.Sku = SKU.Sku'   --(Wan02)                  
      + CHAR(13) + 'WHERE WAVEDETAIL.Wavekey = @c_Wavekey'                          
      + CHAR(13) + 'AND ORDERS.StorerKey = @c_StorerKey'                                                                                            
      + CHAR(13) + 'AND ORDERS.Facility = @c_Facility'                                                                                               
      + CHAR(13) + 'AND ORDERS.Status < ''9''' 
      + CHAR(13) + 'AND ORDERS.SOStatus NOT IN (''CANC'', ''9'')'
      + CHAR(13) + 'AND (ORDERS.MBOLKey IS NULL OR ORDERS.MBOLKey = '''')'  

   SET @c_SQLWhere = @c_SQLWhere 

   SET @c_SQLGroupBy = CHAR(13) + N'GROUP BY'
                     + CHAR(13) +  'WAVEDETAIL.WaveDetailkey'
                     + CHAR(13) + ',ORDERS.OrderKey'
                     + CHAR(13) + ',ORDERS.Loadkey'
                     + CHAR(13) + ',ORDERS.ExternOrderKey'
                     + CHAR(13) + ',ORDERS.[Route]'
                     + CHAR(13) + ',ORDERS.OrderDate'
                     + CHAR(13) + ',ORDERS.DeliveryDate'

   IF @c_GroupBySortField <> ''
   BEGIN
      SET @c_SQLGroupBy= @c_SQLGroupBy+ ', ' + @c_GroupBySortField
   END

   SET @c_SQL = @c_SQL + @c_SQLWhere + @c_SQLBuildByGroupWhere + @c_SQLGroupBy 


   IF @c_SQLBuildByGroupWhere <> ''
   BEGIN
      SET @n_MaxMBOL = 0
          
      SET @c_SQLFieldGroupBy = @c_SQLField

      WHILE @n_BuildGroupCnt < 10
      BEGIN
         SET @c_SQLField = @c_SQLField
                         + CHAR(13) + ','''''

         SET @n_BuildGroupCnt = @n_BuildGroupCnt + 1
      END
      SET @c_SQLBuildByGroup  = N'DECLARE CUR_MBOLGRP CURSOR FAST_FORWARD READ_ONLY FOR '
                              + CHAR(13) + ' SELECT @c_Storerkey'
                              + CHAR(13) + @c_SQLField
                              + CHAR(13) + @c_SQLWhere
                              + CHAR(13) + ' GROUP BY ORDERS.Storerkey ' 
                              + CHAR(13) + @c_SQLFieldGroupBy
                              + CHAR(13) + ' ORDER BY ORDERS.Storerkey ' 
                              + CHAR(13) + @c_SQLFieldGroupBy 
                                                                                                                                                                                                                   
      EXEC SP_EXECUTESQL @c_SQLBuildByGroup 
            , N'@c_StorerKey NVARCHAR(15), @c_Facility NVARCHAR(5), @c_WaveKey NVARCHAR(10)'  
            , @c_StorerKey                                                                                          
            , @c_Facility 
            , @c_Wavekey                                                                                        
                                                                                                                                                                                                                     
      OPEN CUR_MBOLGRP                                                                                                                                         
      FETCH NEXT FROM CUR_MBOLGRP INTO @c_Storerkey
                                    ,  @c_Field01, @c_Field02, @c_Field03, @c_Field04, @c_Field05                                              
                                    ,  @c_Field06, @c_Field07, @c_Field08, @c_Field09, @c_Field10 
                                                         
      WHILE @@FETCH_STATUS = 0                                                                                                                                 
      BEGIN 
         GOTO START_BUILDMBOL                                                                                                                                
         RETURN_BUILDMBOL:                                                                                                                                   
                                                                                                                                                            
         FETCH NEXT FROM CUR_MBOLGRP INTO @c_Storerkey
                                       ,  @c_Field01, @c_Field02, @c_Field03, @c_Field04, @c_Field05                                              
                                       ,  @c_Field06, @c_Field07, @c_Field08, @c_Field09, @c_Field10
      END                                                                                                                                                      
      CLOSE CUR_MBOLGRP                                                                                              
      DEALLOCATE CUR_MBOLGRP

      GOTO END_BUILDMBOL                                                                                                                                       
   END

START_BUILDMBOL:                                                                                                                                            
   TRUNCATE TABLE #tWaveOrder                                                                                                                                     
                                                                                                                                 
   IF @b_debug = 2                                                                                                                                              
   BEGIN                                                                                                                                                       
      SET @d_EndTime_Debug = GETDATE()                                                                                                                         
      PRINT '--Finish Generate SQL Statement--(Check Result In [Select View])'                                                                                 
      PRINT 'Time Cost:' + CONVERT(CHAR(12),@d_EndTime_Debug - @d_StartTime_Debug ,114)                                                                        
      PRINT '--2.Do Execute SQL Statement--'                                                                                                                   
      SET @d_StartTime_Debug = GETDATE()
   END                                                                                                                                                         
 
   SET @c_SQLParms= N'@c_Field01 NVARCHAR(60), @c_Field02 NVARCHAR(60), @c_Field03 NVARCHAR(60), @c_Field04 NVARCHAR(60)'
                  +', @c_Field05 NVARCHAR(60), @c_Field06 NVARCHAR(60), @c_Field07 NVARCHAR(60), @c_Field08 NVARCHAR(60)'
                  +', @c_Field09 NVARCHAR(60), @c_Field10 NVARCHAR(60), @c_StorerKey NVARCHAR(15), @c_Facility NVARCHAR(5), @c_WaveKey NVARCHAR(10)'

   EXEC SP_EXECUTESQL @c_SQL
                     ,@c_SQLParms
                     ,@c_Field01                                                                                                                                      
                     ,@c_Field02                                                                                                                                      
                     ,@c_Field03             
                     ,@c_Field04                                           
                     ,@c_Field05                                                                                                                                      
                     ,@c_Field06                                                                                                                                      
                     ,@c_Field07                                                                                                                                      
                     ,@c_Field08                                                                                                                                      
                     ,@c_Field09                                                                                                                                      
                     ,@c_Field10
                     ,@c_StorerKey 
                     ,@c_Facility
                     , @c_Wavekey    
                         
   IF @b_debug = 2                                                                                                                                              
   BEGIN                                                                                                                                                       
      SET @d_EndTime_Debug = GETDATE()                                                                                                                         
      PRINT '--Finish Execute SQL Statement--(Check Temp DataStore In [Select View])'                                                                          
      PRINT 'Time Cost:' + CONVERT(CHAR(12),@d_EndTime_Debug - @d_StartTime_Debug ,114)                                                                        
      SELECT * FROM #tWaveOrder                                                                                                                                
      PRINT '--3.Do Initial Value Set Up--'                                                                                                                 
      SET @d_StartTime_Debug = GETDATE()                                                                                                                       
   END                                                                                                                                                         
           
   SET @n_MaxOrders =  @n_MaxMBOLOrders                                                                                                                                   
   IF @n_MaxMBOLOrders = 0                                                                                                                                          
   BEGIN                                                                                                                                                       
      SELECT @n_MaxOrders = COUNT(DISTINCT OrderKey)           
      FROM   #tWaveOrder                                                                                                                                       
   END                                                                                                                                                         
                 
   IF @b_debug = 2                                                                                                                                              
   BEGIN                                                                                                                                                       
      SET @d_EndTime_Debug = GETDATE()                                                                                                                         
      PRINT '--Finish Initial Value Setup--'                                                                                                                   
      PRINT 'Time Cost:' + CONVERT(CHAR(12),@d_EndTime_Debug - @d_StartTime_Debug ,114)                                                                        
      PRINT '@n_MaxOrders = ' + CAST(@n_MaxOrders AS NVARCHAR(20)) 
          + ' ,@n_MaxOpenQty = ' +  CAST(@n_MaxOpenQty AS NVARCHAR(20))    
      PRINT '--4.Do Buil Ship Ref. Unit--'                                                                                                                          
      SET @d_StartTime_Debug = GETDATE()                                                                                                                       
   END                                                                                                                                                         
                                                                                                                                                           
   WHILE @@TRANCOUNT > 0                                                                                                                                       
      COMMIT TRAN;                                                                                                                                             

   SET @n_OrderCnt     = 0 
   SET @n_TotalOrderCnt= 0   
   SET @n_TotalOpenQty = 0   
   SET @c_MBOLkey      = '' 
                                                                                                                                                        
   SET @CUR_BUILDMBOL = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT RNUM, OrderKey, Loadkey, ExternOrderKey, [Route], OrderDate, DeliveryDate, [Weight], [Cube]
   FROM #tWaveOrder 
   ORDER BY RNum

   OPEN @CUR_BUILDMBOL 
   FETCH NEXT FROM @CUR_BUILDMBOL INTO  @n_Num, @c_Orderkey, @c_Loadkey, @c_ExternOrderkey
                                      , @c_Route, @d_OrderDate, @d_DeliveryDate
                                      , @n_Weight, @n_Cube                                                                                                                       
   WHILE @@FETCH_STATUS <> -1 
   BEGIN                                                                                                                                                       
      IF @@TRANCOUNT = 0                                                                                                                                       
         BEGIN TRAN;                                                                                                                                           
                          
      IF @n_OpenQty > @n_MaxOpenQty AND @n_MaxOpenQty > 0
      BEGIN
         IF @n_TotalOpenQty = 0 AND @c_MBOLkey = ''
         BEGIN 
            SET @n_Continue = 3 
            SET @n_Err     = 336056                                                                                                                             
            SET @c_ErrMsg  = 'NSQL' + CONVERT(NVARCHAR(6), @n_Err) 
                           + ': No Order to Generate. (ispWMWAVMB01)'                                                                                                                                                 
            GOTO EXIT_SP
         END
         BREAK
      END 

      IF @c_MBOLkey = ''
      BEGIN
         IF @n_MaxMBOL > 0 AND @n_MaxMBOL >= @n_MBOLCnt
         BEGIN
            GOTO END_BUILDMBOL         
         END

         SET @d_StartTime = GETDATE()  
         SET @b_success = 1                                                                                                                                   
         BEGIN TRY
            EXECUTE nspg_GetKey                                                                                                                                      
                  'MBOL'                                                                                                                                           
                  , 10                                                                                                                                                 
                  , @c_MBOLkey  OUTPUT                                                                                                                                 
                  , @b_success  OUTPUT                                                                                                                                   
                  , @n_err      OUTPUT                                                                                                                                       
                  , @c_ErrMsg   OUTPUT                                                                                                                                    
         END TRY
         
         BEGIN CATCH
            SET @n_Err     = 336057                                                                                                                             
            SET @c_ErrMsg  = 'NSQL' + CONVERT(NVARCHAR(6), @n_Err) 
                           + ': Error Executing nspg_GetKey - MBOL. (ispWMWAVMB01)' 
         END CATCH
                                                                                                                                                                     
         IF @b_success <> 1 OR @n_Err <> 0                                                                                                                                   
         BEGIN 
            SET @n_Continue = 3  
            GOTO EXIT_SP
         END  
          
         BEGIN TRY
            INSERT INTO MBOL(MBOLkey, Facility )   
            VALUES(@c_MBOLkey, @c_Facility)         
         END TRY                             
                                                                                                                                    
         BEGIN CATCH                                                                                                                                                
            SET @n_Continue = 3  
            SET @c_ErrMsg  = ERROR_MESSAGE()
            SET @n_Err     = 336058  
            SET @c_ErrMsg  = 'NSQL' + CONVERT(NVARCHAR(6), @n_Err) 
                           + ': Insert Into MBOL Failed. (ispWMWAVMB01) ' 
                           + '(' + @c_ErrMsg + ')' 

            IF (XACT_STATE()) = -1  
            BEGIN
               ROLLBACK TRAN

               WHILE @@TRANCOUNT < @n_StartTCnt
               BEGIN
                  BEGIN TRAN
               END
            END                                                          
            GOTO EXIT_SP     
         END CATCH  
                                                                                                                                                                            
         SET @n_OrderCnt      = 0    
         SET @n_TotalOpenQty  = 0 
         SET @n_TotalWeight   = 0.00
         SET @n_TotalCube     = 0.00
         SET @n_MBOLCnt       = @n_MBOLCnt + 1 
         SET @c_BUILDMBOLKey  = @c_MBOLkey          
      END

      IF @c_MBOLkey = ''
      BEGIN 
         GOTO EXIT_SP
      END

      BEGIN TRAN                                                                                                                                      
      SET @d_EditDate = GETDATE()   
      
      --SET @b_success = 1                                                                                                                                    
      
     BEGIN TRY
         EXEC isp_InsertMBOLDetail 
               @cMBOLKey        = @c_MBOLKey 
            ,  @cFacility       = @c_Facility 
            ,  @cOrderKey       = @c_OrderKey 
            ,  @cLoadKey        = @c_Loadkey 
            ,  @nStdGrossWgt    = @n_Weight
            ,  @nStdCube        = @n_Cube 
            ,  @cExternOrderKey = @c_ExternOrderkey 
            ,  @dOrderDate      = @d_OrderDate 
            ,  @dDelivery_Date  = @d_DeliveryDate 
            ,  @cRoute          = @c_Route 
            ,  @b_Success       = @b_Success OUTPUT
            ,  @n_err           = @n_err     OUTPUT
            ,  @c_errmsg        = @c_errmsg  OUTPUT
      END TRY
      BEGIN CATCH
         SET @n_Err = 336059
         SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + ': Error Executing isp_InsertMBOLDetail. (ispWMWAVMB01)'
                       + '(' + @c_ErrMsg + ')'    

         IF (XACT_STATE()) = -1  
         BEGIN
            ROLLBACK TRAN

            WHILE @@TRANCOUNT < @n_StartTCnt
            BEGIN
               BEGIN TRAN
            END
         END  
      END CATCH

      IF @b_Success = 0 OR @n_Err > 0
      BEGIN
         SET @n_Continue = 3
         GOTO EXIT_SP 
      END

      WHILE @@TRANCOUNT > 0
      BEGIN 
         COMMIT TRAN    
      END

      SET @n_TotalWeight  = @n_TotalWeight + @n_Weight
      SET @n_TotalCube    = @n_TotalCube + @n_Cube

      SET @n_OrderCnt     = @n_OrderCnt + 1    
      SET @n_TotalOrderCnt= @n_TotalOrderCnt + 1 
      SET @n_TotalOpenQty = @n_TotalOpenQty + @n_OpenQty

      IF (@n_OrderCnt >= @n_MaxOrders) OR
         (@n_TotalOpenQty >= @n_MaxOpenQty AND @n_MaxOpenQty > 0)
      BEGIN
         SET @c_MBOLkey = ''
      END

      IF @b_debug = 1 
      BEGIN                      
         SELECT @@TRANCOUNT AS [TranCounts]  
         SELECT @c_MBOLkey 'MBOLkey', @n_OpenQty '@n_OpenQty', @n_TotalOpenQty '@n_TotalOpenQty'          
      END

      FETCH NEXT FROM @CUR_BUILDMBOL INTO  @n_Num, @c_Orderkey, @c_Loadkey, @c_ExternOrderkey
                                         , @c_Route, @d_OrderDate, @d_DeliveryDate
                                         , @n_Weight, @n_Cube   
   END -- WHILE(@@FETCH_STATUS <> -1)                                                                                                                                           
   CLOSE @CUR_BUILDMBOL
   DEALLOCATE @CUR_BUILDMBOL
   
   IF @c_SQLBuildByGroup <> '' 
   BEGIN                                                                                                      
      GOTO RETURN_BUILDMBOL                                                                                                                                    
   END

 END_BUILDMBOL:                                                                                                                                              
                  
   IF @b_debug = 2                                                                                                                                              
   BEGIN                                                                                                                                                       
      SET @d_EndTime_Debug = GETDATE()                                                    
      PRINT '--Finish Build Ship Ref. Unit--'                                                                                     
      PRINT 'Time Cost:' + CONVERT(CHAR(12),@d_EndTime_Debug - @d_StartTime_Debug ,114)                                                                        
      PRINT '--5.Insert Trace Log--'                                                                                                                           
      SET @d_StartTime_Debug = GETDATE()                                                                                                                       
   END                                                                                                                                                         

   SET @c_ErrMsg = ''                                                                                                                                         
   SET @n_Continue = 0                                                                                                                                           
   IF @b_debug = 2                                                                                                                                              
   BEGIN    
      SET @d_EndTime_Debug = GETDATE()                                                                                                                         
      PRINT '--Finish Insert Trace Log--'          
      PRINT 'Time Cost:' + CONVERT(CHAR(12),@d_EndTime_Debug - @d_StartTime_Debug ,114)                                                                        
   END   
                                                                                                                                                                      --                                                                                                                                                            
EXIT_SP:    
   IF @n_Continue = 3                                                                                                                                            
   BEGIN                                                                                                                                                       
      SET @b_Success = 0                                                                                                                                         
      SET @c_ErrMsg = @c_ErrMsg + ' Load #:' + @c_MBOLkey                                                                                                   
 
      IF @@TRANCOUNT > 0 
      BEGIN
         ROLLBACK TRAN
      END                                                                                                                                    
   END                                                                                                                                                         
   ELSE                                                                                                                                                        
   BEGIN                                                                                                                                                       
      WHILE @@TRANCOUNT > 0                                                                                                                    
      BEGIN                                                                                                                                                    
          COMMIT TRAN                                                                                                                                          
      END 
      SET @b_Success = 1                                                                      
   END     
  
   WHILE @@TRANCOUNT < @n_StartTCnt
   BEGIN                                                                                                                         
      BEGIN TRAN                                                                                                                                               
   END

   --REVERT                                                                                                                                                            
   IF @b_debug = 2                                                                                                                                              
   BEGIN                                                                                                                                                       
      PRINT 'SP-ispWMWAVMB01 DEBUG-STOP...'                                               
      PRINT '@b_Success = ' + CAST(@b_Success AS NVARCHAR(2))                                                                                                    
      PRINT '@c_ErrMsg = ' + @c_ErrMsg                                                                                                                        
   END                                                                                                                                                         
-- End Procedure

GO