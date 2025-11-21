SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store Procedure:  isp_loadmani_mbol03                                */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by: YTWan                                                    */
/*                                                                      */
/* Purpose: Change to call SP for Customize                             */
/*        : SOS#300892 - [Adidas] Load Manifest                         */
/*                                                                      */
/* Input Parameters: @c_mbolkey  - mbolkey                              */
/*                                                                      */
/* Output Parameters:  None                                             */
/*                                                                      */
/* Return Status:  None                                                 */
/*                                                                      */
/* Usage:  Used for report dw = r_dw_load_manifest_mbol03               */
/*                                                                      */
/* Local Variables:                                                     */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/* 08-Apr-2014  YTWan   1.1   To show more externorderkey (Wan01)       */
/* 13-Apr-2014  TLTING  1.1   SQL2012                                   */
/* 28-Jan-2019  TLTING_ext 1.2  enlarge externorderkey field length      */
/************************************************************************/
CREATE PROC [dbo].[isp_loadmani_mbol03] (
     @c_mbolkey   NVARCHAR(10)
)
 AS
BEGIN
   SET NOCOUNT ON 
   SET ANSI_NULLS OFF 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

    DECLARE @n_continue       INT 
         ,  @c_errmsg         NVARCHAR(255) 
         ,  @b_success        INT 
         ,  @n_err            INT 
         ,  @n_StartTCnt      INT

         ,  @c_SQL            NVARCHAR(MAX)
         ,  @c_Storerkey      NVARCHAR(15)

         ,  @c_Facility       NVARCHAR(5)
         ,  @c_DriverName     NVARCHAR(30)
         ,  @dt_adddate       DATETIME
         ,  @c_Remarks        NVARCHAR(40)
         ,  @c_Loadkey        NVARCHAR(10)
         ,  @c_ExternOrderkey NVARCHAR(50)   --tlting_ext
         ,  @c_Consigneekey   NVARCHAR(15)
         ,  @dt_DeliveryDate  DATETIME

         ,  @c_c_Company      NVARCHAR(45)  
         ,  @c_c_Address1     NVARCHAR(45) 
         ,  @c_c_Address2     NVARCHAR(45) 
         ,  @c_c_Address3     NVARCHAR(45) 
         ,  @c_c_Address4     NVARCHAR(45) 
         ,  @c_c_Zip          NVARCHAR(18) 
         ,  @c_c_City         NVARCHAR(45) 
         ,  @c_Route          NVARCHAR(10)  
         ,  @c_BuyerPO        NVARCHAR(20) 

         ,  @n_NoOfCartons    INT


         ,  @c_ExternSO       NVARCHAR(250)
         ,  @c_MultiExternSO  NVARCHAR(1000)   --(Wan01)

         ,  @n_ShowAddresses  INT
         ,  @n_ShowBuyerPO    INT
         ,  @n_ShowMultiExtSO INT

   SET @n_StartTCnt = @@TRANCOUNT

   WHILE @@TRANCOUNT > 0 
   BEGIN
      COMMIT TRAN
   END
     
   CREATE TABLE #TMP_LOAD
      (  Facility             NVARCHAR(5)    
      ,  Storerkey            NVARCHAR(15)
      ,  MBOLKey              NVARCHAR(10)
      ,  DriverName           NVARCHAR(30)
      ,  Remarks              NVARCHAR(40)
      ,  AddDate              DATETIME
      ,  Loadkey              NVARCHAR(10)
      ,  MultiExternOrderkey  NVARCHAR(1000)   --(Wan01)  
      ,  Consigneekey         NVARCHAR(15)      
      ,  DeliveryDate         DATETIME   
      ,  c_Company            NVARCHAR(45)  
      ,  c_Address1           NVARCHAR(45) 
      ,  c_Address2           NVARCHAR(45) 
      ,  c_Address3           NVARCHAR(45) 
      ,  c_Address4           NVARCHAR(45) 
      ,  c_Zip                NVARCHAR(18) 
      ,  c_City               NVARCHAR(45) 
      ,  Route                NVARCHAR(10)   
      ,  BuyerPO              NVARCHAR(20)
      ,  Cartons              INT
      ,  LM_SG                NVARCHAR(1)
      )

   BEGIN TRAN
   DECLARE CUR_LOAD CURSOR FAST_FORWARD READ_ONLY FOR
   SELECT   DISTINCT MH.Facility
         ,  OH.Storerkey
         ,  ISNULL(RTRIM(MH.DriverName),'')
         ,  ISNULL(RTRIM(CONVERT(NVARCHAR(40),MH.Remarks)),'')
         ,  MH.AddDate 
         ,  CASE WHEN ISNULL(SC.Svalue,'') = '1' THEN ''
                 ELSE ISNULL(RTRIM(OH.Loadkey),'') END  
         ,  CASE WHEN ISNULL(SC.Svalue,'') = '1' THEN ISNULL(RTRIM(OH.ExternOrderkey),'')
                 ELSE '' END 
         ,  ISNULL(RTRIM(OH.Consigneekey),'')    
         ,  OH.DeliveryDate                    
   FROM MBOL         MH WITH (NOLOCK)
   JOIN MBOLDETAIL   MD WITH (NOLOCK)  ON (MH.MBOLKey = MD.MBolKey)
   JOIN ORDERS       OH WITH (NOLOCK)  ON (MD.OrderKey = OH.OrderKey)
   LEFT OUTER JOIN STORERCONFIG SC WITH (NOLOCK) ON ( OH.Storerkey = SC.Storerkey AND OH.Facility = SC.Facility
                                                 AND  SC.Configkey='LoadManiMBOL_SG' AND SC.Svalue='1' )
   WHERE ( MH.MbolKey = @c_mbolkey )

   OPEN CUR_LOAD
   
   FETCH NEXT FROM CUR_LOAD INTO  @c_Facility
                                 ,@c_Storerkey
                                 ,@c_DriverName
                                 ,@c_Remarks
                                 ,@dt_AddDate
                                 ,@c_Loadkey
                                 ,@c_ExternOrderkey
                                 ,@c_Consigneekey
                                 ,@dt_DeliveryDate                                        
                             
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      SET @c_c_Company = ''
      SET @c_c_Address1= ''
      SET @c_c_Address2= ''
      SET @c_c_Address3= ''
      SET @c_c_Address4= ''
      SET @c_c_Zip     = ''
      SET @c_c_City    = ''
      SET @c_Route     = ''
      SET @c_BuyerPO   = ''
      
      SET @c_ExternSO      = ''
      SET @c_MultiExternSO = ''

      SET @n_ShowAddresses = 0
      SET @n_ShowBuyerPO   = 0
      SET @n_ShowMultiExtSO= 0
      SELECT @n_ShowAddresses = MAX(CASE WHEN Code = 'ShowAddresses' THEN 1 ELSE 0 END)
            ,@n_ShowBuyerPO   = MAX(CASE WHEN Code = 'ShowBuyerPO' THEN 1 ELSE 0 END)
            ,@n_ShowMultiExtSO= MAX(CASE WHEN Code = 'ShowMultiExtSO' THEN 1 ELSE 0 END)
      FROM CODELKUP WITH (NOLOCK)
      WHERE ListName = 'REPORTCFG'
      AND   Storerkey= @c_Storerkey
      AND   Long     = 'r_dw_load_manifest_mbol03'
      AND   (Short    IS NULL OR Short = 'N')
     
      SELECT TOP 1
             @c_c_Company  = ISNULL(OH.c_Company,'')
            ,@c_c_Address1 = CASE WHEN @n_ShowAddresses = 1 THEN ISNULL(OH.c_Address1,'') ELSE '' END
            ,@c_c_Address2 = CASE WHEN @n_ShowAddresses = 1 THEN ISNULL(OH.c_Address2,'') ELSE '' END
            ,@c_c_Address3 = CASE WHEN @n_ShowAddresses = 1 THEN ISNULL(OH.c_Address3,'') ELSE '' END
            ,@c_c_Address4 = CASE WHEN @n_ShowAddresses = 1 THEN ISNULL(OH.c_Address4,'') ELSE '' END
            ,@c_c_Zip      = CASE WHEN @n_ShowAddresses = 1 THEN ISNULL(OH.c_Zip,'')      ELSE '' END
            ,@c_c_City     = CASE WHEN @n_ShowAddresses = 1 THEN ISNULL(OH.c_City,'')     ELSE '' END
            ,@c_BuyerPO    = CASE WHEN @n_ShowBuyerPO = 1   THEN ISNULL(OH.BuyerPO,'')    ELSE '' END
            ,@c_Route      = ISNULL(OH.Route,'')
      FROM ORDERS OH  WITH (NOLOCK)
      WHERE OH.Loadkey        = CASE WHEN @c_Loadkey = '' THEN OH.Loadkey ELSE @c_Loadkey END
      AND   OH.ExternOrderkey = CASE WHEN @c_ExternOrderkey = '' THEN OH.ExternOrderkey ELSE @c_ExternOrderkey END
      AND   OH.Consigneekey = @c_Consigneekey
      AND   OH.DeliveryDate = @dt_DeliveryDate

      SET @n_NoOfCartons = 0
      SELECT @n_NoOfCartons = COUNT(DISTINCT CASE WHEN @c_ExternOrderkey = '' THEN PD.DropID 
                                                  ELSE OD.Userdefine01 + OD.Userdefine02
                                                  END)
      FROM ORDERS       OH WITH (NOLOCK)
      JOIN ORDERDETAIL  OD WITH (NOLOCK) ON (OH.Orderkey = OD.Orderkey)
      LEFT JOIN PACKHEADER   PH WITH (NOLOCK) ON (OH.Orderkey = PH.Orderkey)
      LEFT JOIN PACKDETAIL   PD WITH (NOLOCK) ON (PH.PickSlipNo = PD.PickSlipNo)
      WHERE OH.Loadkey        = CASE WHEN @c_Loadkey = '' THEN OH.Loadkey ELSE @c_Loadkey END
      AND   OH.ExternOrderkey = CASE WHEN @c_ExternOrderkey = '' THEN OH.ExternOrderkey ELSE @c_ExternOrderkey END
      AND   OH.Consigneekey = @c_Consigneekey
      AND   OH.DeliveryDate = @dt_DeliveryDate

      DECLARE CUR_EXTSO CURSOR FAST_FORWARD READ_ONLY FOR
      SELECT   DISTINCT ISNULL(RTRIM(OH.ExternOrderkey),'')
      FROM ORDERS OH  WITH (NOLOCK)
      WHERE OH.Loadkey        = CASE WHEN @c_Loadkey = '' THEN OH.Loadkey ELSE @c_Loadkey END
      AND   OH.ExternOrderkey = CASE WHEN @c_ExternOrderkey = '' THEN OH.ExternOrderkey ELSE @c_ExternOrderkey END
      AND   OH.Consigneekey = @c_Consigneekey
      AND   OH.DeliveryDate = @dt_DeliveryDate
      AND   @n_ShowMultiExtSO = 1

      OPEN CUR_EXTSO
      
      FETCH NEXT FROM CUR_EXTSO INTO @c_ExternSO

      WHILE @@FETCH_STATUS <> -1
      BEGIN
         SET @c_MultiExternSO = @c_MultiExternSO + @c_ExternSO + ' '
         FETCH NEXT FROM CUR_EXTSO INTO @c_ExternSO
      END
      CLOSE CUR_EXTSO
      DEALLOCATE CUR_EXTSO

      SET @c_MultiExternSO = CASE WHEN LEN(@c_MultiExternSO) > 0 THEN SUBSTRING(@c_MultiExternSO,1, LEN(@c_MultiExternSO)) ELSE '' END

      INSERT INTO #TMP_LOAD
            (  Facility
            ,  Storerkey
            ,  MBOLKey
            ,  DriverName
            ,  Remarks
            ,  AddDate
            ,  Loadkey
            ,  MultiExternOrderkey
            ,  Consigneekey
            ,  DeliveryDate
            ,  c_Company
            ,  c_Address1
            ,  c_Address2
            ,  c_Address3
            ,  c_Address4
            ,  c_Zip
            ,  c_City
            ,  BuyerPO
            ,  Route
              ,  Cartons
            ,  LM_SG
            )
      VALUES
            (  @c_Facility
            ,  @c_Storerkey
            ,  @c_MbolKey
            ,  @c_DriverName
            ,  @c_Remarks
            ,  @dt_AddDate
            ,  CASE WHEN @c_Loadkey = '' THEN @c_ExternOrderkey ELSE @c_Loadkey END
            ,  @c_MultiExternSO
            ,  @c_Consigneekey
            ,  @dt_DeliveryDate
            ,  @c_c_Company
            ,  @c_c_Address1
            ,  @c_c_Address2
            ,  @c_c_Address3
            ,  @c_c_Address4
            ,  @c_c_Zip
            ,  @c_c_City
            ,  @c_BuyerPO
            ,  @c_Route

            ,  @n_NoOfCartons
            ,  CASE WHEN @c_Loadkey = '' THEN '1' ELSE '0' END
            )


      FETCH NEXT FROM CUR_LOAD INTO  @c_Facility
                                    ,@c_Storerkey
                                    ,@c_DriverName
                                    ,@c_Remarks
                                    ,@dt_AddDate
                                    ,@c_Loadkey
                                    ,@c_ExternOrderkey
                                    ,@c_Consigneekey
                                    ,@dt_DeliveryDate
   END
   CLOSE CUR_LOAD
   DEALLOCATE CUR_LOAD

   QUIT_SP:
   SELECT Facility
      ,  Storerkey
      ,  MBOLKey
      ,  DriverName
      ,  Remarks
      ,  AddDate
      ,  Loadkey
      ,  MultiExternOrderkey
      ,  Consigneekey
      ,  DeliveryDate
      ,  c_Company
      ,  c_Address1
      ,  c_Address2
      ,  c_Address3
      ,  c_Address4
      ,  c_Zip
      ,  c_City
      ,  Route
      ,  BuyerPO
      ,  Cartons
      ,  LM_SG
      ,  @n_ShowAddresses
      ,  @n_ShowBuyerPO
      ,  @n_ShowMultiExtSO
   FROM #TMP_LOAD
   ORDER BY Route
         ,  Consigneekey
         ,  Loadkey
         ,  DeliveryDate

   WHILE @@TRANCOUNT < @n_StartTCnt
   BEGIN
      BEGIN TRAN 
   END

   /* #INCLUDE <SPTPA01_2.SQL> */  
   IF @n_continue=3  -- Error Occured - Process And Return  
   BEGIN  
      SELECT @b_success = 0  
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT >= @n_StartTCnt  
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
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'isp_loadmani_mbol03'  
      --RAISERROR @n_err @c_errmsg 
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012  
      RETURN  
   END  
   ELSE  
   BEGIN  
      SELECT @b_success = 1  
      WHILE @@TRANCOUNT > @n_StartTCnt  
      BEGIN  
         COMMIT TRAN  
      END  
   END

END

GO