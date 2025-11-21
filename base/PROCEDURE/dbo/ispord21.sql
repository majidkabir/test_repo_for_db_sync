SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: ispORD21                                           */
/* Creation Date: 25-May-2023                                           */
/* Copyright: MAERSK                                                    */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-22697 - [AU] LEVIS ORDER INSERT TRIGGER - NEW           */
/*                                                                      */
/* Called By: isp_OrderTrigger_Wrapper from Orders Trigger              */
/*            Storerconfig: OrdersTrigger_SP                            */
/*                                                                      */
/* GitLab Version: 1.0                                                  */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author   Ver  Purposes                                  */
/* 25-May-2023  WLChooi  1.0  DevOps Combine Script                     */
/* 27-Jul-2023  WLChooi  1.1  WMS-22697 - Logic change (WL01)           */
/************************************************************************/
CREATE   PROCEDURE [dbo].[ispORD21]
   @c_Action    NVARCHAR(10)
 , @c_Storerkey NVARCHAR(15)
 , @b_Success   INT           OUTPUT
 , @n_Err       INT           OUTPUT
 , @c_ErrMsg    NVARCHAR(250) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_Continue     INT
         , @n_StartTCnt    INT
         , @c_BillToKey    NVARCHAR(100)
         , @c_DocType      NVARCHAR(20)
         , @c_Orderkey     NVARCHAR(10)
         , @c_Orderkey_HDR NVARCHAR(10)
         , @c_BuyerPO      NVARCHAR(50)

   DECLARE @c_C_Contact1      NVARCHAR(100)
         , @c_C_Contact2      NVARCHAR(100)
         , @c_C_Company       NVARCHAR(100)
         , @c_C_Address1      NVARCHAR(100)
         , @c_C_Address2      NVARCHAR(100)
         , @c_C_City          NVARCHAR(100)
         , @c_C_Zip           NVARCHAR(100)
         , @c_C_Country       NVARCHAR(100)
         , @c_C_Phone1        NVARCHAR(100)
         , @c_C_Fax1          NVARCHAR(100)
         , @c_C_Fax2          NVARCHAR(100)
         , @c_Door            NVARCHAR(100)
         , @c_Route           NVARCHAR(100)
         , @c_Stop            NVARCHAR(100)
         , @c_ContainerType   NVARCHAR(100)
         , @n_ContainerQty    INT
         , @n_GrossWeight     FLOAT
         , @c_UserDefine02    NVARCHAR(100)
         , @c_UserDefine08    NVARCHAR(100)
         , @c_DeliveryNote    NVARCHAR(100)
         , @c_SpecialHandling NVARCHAR(1)
         , @c_RoutingTool     NVARCHAR(100)
         , @c_C_State         NVARCHAR(100)
         , @c_Notes           NVARCHAR(4000)
         , @c_SOStatus        NVARCHAR(50)
         , @c_Shipperkey      NVARCHAR(50)
         , @c_Status          NVARCHAR(50)
         , @c_Type            NVARCHAR(50)
         , @c_Address1_New    NVARCHAR(100)
         , @c_Address1        NVARCHAR(100)
         , @c_SOStatus_DEL    NVARCHAR(50)
         , @c_Status_DEL      NVARCHAR(50)
         , @c_VAT             NVARCHAR(50)

   SELECT @n_Continue = 1
        , @n_StartTCnt = @@TRANCOUNT
        , @n_Err = 0
        , @c_ErrMsg = ''
        , @b_Success = 1

   IF @c_Action NOT IN ( 'INSERT', 'UPDATE' )
      GOTO QUIT_SP

   IF OBJECT_ID('tempdb..#INSERTED') IS NULL
   BEGIN
      GOTO QUIT_SP
   END

   DECLARE CUR_LOOP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT DISTINCT I.Orderkey
   FROM #INSERTED I

   OPEN CUR_LOOP

   FETCH NEXT FROM CUR_LOOP
   INTO @c_Orderkey

   WHILE @@FETCH_STATUS <> -1
   BEGIN
      SET @c_BillToKey = N''
      SET @c_DocType = N''
      SET @c_Storerkey = N''
      SET @c_Orderkey_HDR = N''

      SELECT @c_BillToKey = TRIM(ISNULL(I.BillToKey, ''))
           , @c_Storerkey = TRIM(ISNULL(I.Storerkey, ''))
           , @c_BuyerPO = TRIM(ISNULL(I.BuyerPO,''))
           , @c_SOStatus = TRIM(ISNULL(I.SOStatus,''))
           , @c_Shipperkey = TRIM(ISNULL(I.Shipperkey,''))
           , @c_Status = TRIM(ISNULL(I.[Status],''))
           , @c_Type = TRIM(ISNULL(I.[Type],''))
           , @c_Address1_New = TRIM(ISNULL(I.C_Address1,''))
      FROM #INSERTED I
      WHERE I.Orderkey = @c_Orderkey

      IF @c_Action IN ( 'INSERT' )
      BEGIN
         IF NOT EXISTS (  SELECT 1
                          FROM CODELKUP CL (NOLOCK)
                          WHERE CL.LISTNAME = 'LVSB2CCUST' AND CL.Storerkey = @c_Storerkey 
                          AND CL.Code = @c_BillToKey)
         BEGIN
            GOTO NEXT_LOOP
         END

         SELECT @c_BuyerPO = FDS.ColValue 
         FROM dbo.fnc_DelimSplit('-', @c_BuyerPO) FDS
         WHERE FDS.SeqNo = 1

         SELECT TOP 1 @c_Orderkey_HDR = OH.Orderkey
         FROM ORDERS OH (NOLOCK)
         WHERE OH.StorerKey = @c_Storerkey
         AND OH.[Status] = '0'
         AND OH.OrderKey <> @c_Orderkey
         AND (OH.BuyerPO IS NOT NULL AND OH.BuyerPO <> '')
         AND (OH.ExternOrderKey IS NOT NULL AND OH.ExternOrderKey <> '')
         AND OH.BuyerPO = @c_BuyerPO
         AND OH.ExternOrderKey = @c_BuyerPO

         IF ISNULL(@c_Orderkey_HDR,'') <> ''
         BEGIN
            SELECT @c_C_Contact1      = ISNULL(C_Contact1,'')
                 , @c_C_Contact2      = ISNULL(C_Contact2,'')
                 , @c_C_Company       = ISNULL(C_Company,'')
                 , @c_C_Address1      = ISNULL(C_Address1,'')
                 , @c_C_Address2      = ISNULL(C_Address2,'')
                 , @c_C_City          = ISNULL(C_City,'')
                 , @c_C_Zip           = ISNULL(C_Zip,'')
                 , @c_C_Country       = ISNULL(C_Country,'')
                 , @c_C_Phone1        = ISNULL(C_Phone1,'')
                 , @c_C_Fax1          = ISNULL(C_Fax1,'')
                 , @c_C_Fax2          = ISNULL(C_Fax2,'')
                 , @c_Door            = ISNULL(Door,'')
                 , @c_Route           = ISNULL([Route],'')
                 , @c_Stop            = ISNULL([Stop],'')
                 , @c_ContainerType   = ISNULL(ContainerType,'')
                 , @n_ContainerQty    = ISNULL(ContainerQty,0)
                 , @n_GrossWeight     = ISNULL(GrossWeight,0.00)
                 , @c_UserDefine02    = ISNULL(UserDefine02,'')
                 , @c_UserDefine08    = ISNULL(UserDefine08,'')
                 , @c_DeliveryNote    = ISNULL(DeliveryNote,'')
                 , @c_SpecialHandling = ISNULL(SpecialHandling,'')
                 , @c_RoutingTool     = ISNULL(RoutingTool,'')
                 , @c_C_State         = ISNULL(C_State,'')
                 , @c_Notes           = ISNULL(Notes,'')
                 , @c_VAT             = ISNULL(C_VAT,'')
            FROM ORDERS (NOLOCK)
            WHERE Orderkey = @c_Orderkey_HDR
         END
         ELSE
         BEGIN
            UPDATE ORDERS
            SET SOStatus = 'NoDinFile'
            WHERE Orderkey = @c_Orderkey

            SET @c_SOStatus = 'NoDinFile'

            IF @@ERROR <> 0
            BEGIN
               SET @n_continue = 3    
               SET @n_err = 61531 -- Should Be Set To The SQL Errmessage but I don't know how to do so. 
               SET @c_errmsg = 'NSQL'+ CONVERT(NVARCHAR(5), @n_err) +': Update SOStatus for Orders#: ' + @c_Orderkey +' Failed! (ispORD21)'   
               GOTO QUIT_SP 
            END

            GOTO NEXT_LOOP
         END
      END

      UPDATE_RESULT:

      IF @c_Action IN ( 'INSERT' ) AND ISNULL(@c_Orderkey_HDR,'') <> ''
      BEGIN
         IF @c_C_State = 'NZ'
         BEGIN
            IF LEFT(TRIM(@c_C_Zip),1) IN ('7','8','9')
            BEGIN
               SET @c_C_State = 'SI'
            END
            ELSE
            BEGIN
               SET @c_C_State = 'NI'
            END
         END

         UPDATE ORDERS
         SET [Type]           = 'B2C'
           , C_Contact1       = CASE WHEN ISNULL(@c_C_Contact1,'') <> ''      THEN @c_C_Contact1      ELSE C_Contact1      END
           , C_Contact2       = CASE WHEN ISNULL(@c_C_Contact2,'') <> ''      THEN @c_C_Contact2      ELSE C_Contact2      END
           , C_Company        = CASE WHEN ISNULL(@c_C_Company,'') <> ''       THEN @c_C_Company       ELSE C_Company       END
           , C_Address1       = CASE WHEN ISNULL(@c_C_Address1,'') <> ''      THEN @c_C_Address1      ELSE C_Address1      END
           , C_Address2       = CASE WHEN ISNULL(@c_C_Address2,'') <> ''      THEN @c_C_Address2      ELSE C_Address2      END
           , C_City           = CASE WHEN ISNULL(@c_C_City,'') <> ''          THEN @c_C_City          ELSE C_City          END
           , C_Zip            = CASE WHEN ISNULL(@c_C_Zip,'') <> ''           THEN @c_C_Zip           ELSE C_Zip           END
           , C_Country        = CASE WHEN ISNULL(@c_C_Country,'') <> ''       THEN @c_C_Country       ELSE C_Country       END
           , C_Phone1         = CASE WHEN ISNULL(@c_C_Phone1,'') <> ''        THEN @c_C_Phone1        ELSE C_Phone1        END
           , C_Fax1           = CASE WHEN ISNULL(@c_C_Fax1,'') <> ''          THEN @c_C_Fax1          ELSE C_Fax1          END
           , C_Fax2           = CASE WHEN ISNULL(@c_C_Fax2,'') <> ''          THEN @c_C_Fax2          ELSE C_Fax2          END
           , Door             = CASE WHEN ISNULL(@c_Door,'') <> ''            THEN @c_Door            ELSE Door            END
           , [Route]          = CASE WHEN ISNULL(@c_Route,'') <> ''           THEN @c_Route           ELSE [Route]         END
           , [Stop]           = CASE WHEN ISNULL(@c_Stop,'') <> ''            THEN @c_Stop            ELSE [Stop]          END
           , ContainerType    = CASE WHEN ISNULL(@c_ContainerType,'') <> ''   THEN @c_ContainerType   ELSE ContainerType   END
           , ContainerQty     = CASE WHEN ISNULL(@n_ContainerQty,0) <> 0      THEN @n_ContainerQty    ELSE ContainerQty    END
           , GrossWeight      = CASE WHEN ISNULL(@n_GrossWeight,0.00) <> 0.00 THEN @n_GrossWeight     ELSE GrossWeight     END
           , UserDefine02     = CASE WHEN ISNULL(@c_UserDefine02,'') <> ''    THEN @c_UserDefine02    ELSE UserDefine02    END
           , UserDefine08     = CASE WHEN ISNULL(@c_UserDefine08,'') <> ''    THEN @c_UserDefine08    ELSE UserDefine08    END
           , DeliveryNote     = CASE WHEN ISNULL(@c_DeliveryNote,'') <> ''    THEN @c_DeliveryNote    ELSE DeliveryNote    END
           , SpecialHandling  = CASE WHEN ISNULL(@c_SpecialHandling,'') <> '' THEN @c_SpecialHandling ELSE SpecialHandling END
           , RoutingTool      = CASE WHEN ISNULL(@c_RoutingTool,'') <> ''     THEN @c_RoutingTool     ELSE RoutingTool     END
           , C_ISOCntryCode   = CASE WHEN ISNULL(@c_C_Country,'') <> ''       THEN @c_C_Country       ELSE C_Country       END
           , Notes            = CASE WHEN ISNULL(@c_Notes,'') <> ''           THEN @c_Notes           ELSE Notes           END
           , C_State          = CASE WHEN ISNULL(@c_C_State,'') <> ''         THEN @c_C_State         ELSE C_State         END
           , SOStatus         = CASE WHEN SOStatus <> '0' THEN '0' ELSE SOStatus END
           , C_VAT            = CASE WHEN ISNULL(@c_VAT,'') <> '' THEN @c_VAT ELSE C_VAT END
           , TrafficCop       = NULL
           , ArchiveCop       = NULL
           , EditDate         = GETDATE()
           , EditWho          = SUSER_SNAME()
         WHERE OrderKey = @c_Orderkey

         IF @@ERROR <> 0
         BEGIN
            SET @n_continue = 3    
            SET @n_err = 61533 -- Should Be Set To The SQL Errmessage but I don't know how to do so. 
            SET @c_errmsg = 'NSQL'+ CONVERT(NVARCHAR(5), @n_err) +': Update Orders#: ' + @c_Orderkey +' Failed! (ispORD21)'   
            GOTO QUIT_SP 
         END
         
         DELETE FROM dbo.ORDERS
         WHERE OrderKey = @c_Orderkey_HDR

         IF @@ERROR <> 0
         BEGIN
            SET @n_continue = 3    
            SET @n_err = 61534 -- Should Be Set To The SQL Errmessage but I don't know how to do so. 
            SET @c_errmsg = 'NSQL'+ CONVERT(NVARCHAR(5), @n_err) +': Delete Orders#: ' + @c_Orderkey_HDR +' Failed! (ispORD21)'   
            GOTO QUIT_SP 
         END
      END

      NEXT_LOOP:
      IF @c_Action IN ( 'INSERT' ) AND ISNULL(@c_Shipperkey,'') = '' AND @c_SOStatus <> 'NoDinFile'
      BEGIN
         UPDATE O WITH (ROWLOCK)
         SET O.Shipperkey = CASE WHEN ISNULL(CL1.Short,'') = '' THEN ISNULL(CLK.Short,'') ELSE ISNULL(CL1.Short,'') END   --WL01
         FROM ORDERS O
         LEFT JOIN CODELKUP CLK (NOLOCK) ON O.STORERKEY = CLK.Storerkey
                                        AND O.C_COUNTRY = CLK.Code AND O.[TYPE] = CLK.code2 
                                        AND CLK.LISTNAME = 'OHSHPKMAP'
         LEFT JOIN CODELKUP CL1 (NOLOCK) ON O.STORERKEY = CL1.Storerkey                          --WL01
                                        AND O.C_COUNTRY = CL1.Code AND O.BillToKey = CL1.code2   --WL01
                                        AND CL1.LISTNAME = 'OHSHPKMAP'                           --WL01
         WHERE O.OrderKey = @c_Orderkey

         IF @@ERROR <> 0
         BEGIN
            SET @n_continue = 3    
            SET @n_err = 61534 -- Should Be Set To The SQL Errmessage but I don't know how to do so. 
            SET @c_errmsg = 'NSQL'+ CONVERT(NVARCHAR(5), @n_err) +': Update Shipperkey for Orders#: ' + @c_Orderkey +' Failed! (ispORD21)'   
            GOTO QUIT_SP 
         END
      END

      IF @c_Action IN ( 'UPDATE' )
      BEGIN
         IF OBJECT_ID('tempdb..#DELETED') IS NULL
         BEGIN
            GOTO QUIT_SP
         END

         SELECT @c_BillToKey = TRIM(ISNULL(D.BillToKey, ''))
              , @c_Address1  = TRIM(ISNULL(D.C_Address1,''))
              , @c_SOStatus_DEL = TRIM(ISNULL(D.SOStatus,''))
              , @c_Status_DEL = TRIM(ISNULL(D.[Status],''))
         FROM #DELETED D
         WHERE D.Orderkey = @c_Orderkey

         IF EXISTS (  SELECT 1
                      FROM CODELKUP CL (NOLOCK)
                      WHERE CL.LISTNAME = 'LVSB2CCUST' AND CL.Storerkey = @c_Storerkey 
                      AND CL.Code = @c_BillToKey) AND @c_SOStatus_DEL = 'NoDinFile' AND @c_Status_DEL = '0'
         BEGIN
            IF @c_Type = 'B2C' AND ISNULL(@c_Address1,'') <> ISNULL(@c_Address1_New,'')
            BEGIN
               UPDATE ORDERS
               SET SOStatus = '0'
               WHERE Orderkey = @c_Orderkey
               
               SET @c_SOStatus = '0'
               
               IF @@ERROR <> 0
               BEGIN
                  SET @n_continue = 3    
                  SET @n_err = 61532 -- Should Be Set To The SQL Errmessage but I don't know how to do so. 
                  SET @c_errmsg = 'NSQL'+ CONVERT(NVARCHAR(5), @n_err) +': Update SOStatus for Orders#: ' + @c_Orderkey +' Failed! (ispORD21)'   
                  GOTO QUIT_SP 
               END
            END
         END
      END

      FETCH NEXT FROM CUR_LOOP
      INTO @c_Orderkey
   END
   CLOSE CUR_LOOP
   DEALLOCATE CUR_LOOP

   QUIT_SP:

   IF CURSOR_STATUS('LOCAL', 'CUR_LOOP') IN ( 0, 1 )
   BEGIN
      CLOSE CUR_LOOP
      DEALLOCATE CUR_LOOP
   END

   IF @n_Continue = 3 -- Error Occured - Process AND Return
   BEGIN
      SELECT @b_Success = 0
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt
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
      EXECUTE dbo.nsp_logerror @n_Err, @c_ErrMsg, 'ispORD21'
      --RAISERROR (@c_Errmsg, 16, 1) WITH SETERROR    -- SQL2012
      RETURN
   END
   ELSE
   BEGIN
      SELECT @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
      RETURN
   END
END

GO