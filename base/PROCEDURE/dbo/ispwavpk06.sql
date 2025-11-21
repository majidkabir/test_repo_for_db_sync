SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* SP: ispWAVPK05                                                       */
/* Creation Date: 28 MAR 2019                                           */
/* Copyright: IDS                                                       */
/* Written by: CSCHONG                                                  */
/*                                                                      */
/* Purpose:WMS-8296-D070 to D086 Outbound- Generate Packing From Picking*/
/*                                                                      */
/* Usage:                                                               */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* RDTMsg :                                                             */
/*                                                                      */
/* PVCS Version: 1.3                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/*                                                                      */
/* Updates:                                                             */
/* Date           Author   Ver   Purposes                               */
/* 22-Apr-2019    CSCHONG  1.1   WMS-8296 - revised sorting (CS01)      */
/* 01-JUL-2019    CSCHONG  1.2   WMS-9405 - Add new update (CS02)       */
/************************************************************************/
CREATE PROC [dbo].[ispWAVPK06]
(
    @c_WaveKey       NVARCHAR(20)
   ,@b_Success       INT            OUTPUT
   ,@n_err           INT            OUTPUT
   ,@c_ErrMsg        NVARCHAR(250)  OUTPUT  
   ,@c_Source        NVARCHAR(10) = ''    
)
AS
BEGIN
   SET NOCOUNT ON 
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @n_StartTCnt             INT
         , @n_Continue              INT = 1
         , @b_debug                 BIT = 0

   DECLARE @n_VAS                   INT = 0         
         , @n_SplitPickDetail       BIT

         , @n_Cnt                   INT
         
         , @n_CartonCube_X16        FLOAT
         , @n_CartonCube_X18        FLOAT     
         , @n_PackFactor            FLOAT
         , @n_CartonCube            FLOAT
                
         , @c_Facility              NVARCHAR(5)                                                                           
                                                         
         , @c_DocumentKey           NVARCHAR(10)
         , @c_Loadkey               NVARCHAR(10)
         , @c_PickZone              NVARCHAR(10)
         , @c_Site                  NVARCHAR(30)
         , @c_Storerkey             NVARCHAR(15)
         , @c_Storerkey_Prev        NVARCHAR(15)
         , @c_Sku                   NVARCHAR(20)
         , @c_Sku_Prev              NVARCHAR(20)
         , @c_Division              NVARCHAR(30)   -- SKU.BUSR7
         , @c_Material              NVARCHAR(10)   -- SKU.ItemClass
         , @c_SkuCGD                NVARCHAR(18)   -- SKU.SUSR3
         , @c_CartonType            NVARCHAR(10)
         , @c_CartonGroup           NVARCHAR(10)
         , @c_Orderkey              NVARCHAR(10)
         , @c_GOrderkey             NVARCHAR(10)
         , @c_OrderLineNumber       NVARCHAR(5)
         , @c_Lottable09            NVARCHAR(30) 
         , @c_PreLottable09         NVARCHAR(30)
         
         , @n_Qty                   INT  

         , @c_PickDetailKey         NVARCHAR(10)
         , @c_NewPickDetailkey      NVARCHAR(10)

         , @n_CartonNo              INT
         , @c_PickSlipNo            NVARCHAR(10)
         , @c_GetPickSlipNo         NVARCHAR(10)


         , @c_NIKEPackByCGD            NVARCHAR(30)
         , @c_LPGenPackFromPicked      NVARCHAR(30)
         , @c_WaveGenPackFromPicked_SP NVARCHAR(30)


         , @n_PackQtyIndicator      INT             
         , @n_PackQtyLimit          INT             
         , @n_Add2CartonID          INT             
         , @n_Add2RowID             INT             
         , @n_PackCube              FLOAT           
         , @n_TotalPackCube         FLOAT           
         , @c_Status                NVARCHAR(10)    

   DECLARE @CUR_PD                  CURSOR
         , @CUR_ORD                 CURSOR
         , @CUR_SKUCTN              CURSOR
         , @CUR_MIXCTN              CURSOR

   DECLARE @TLASTCTN TABLE
      (
         RowID             INT            NOT NULL IDENTITY(1,1) PRIMARY KEY
      ,  Loadkey           NVARCHAR(10)   NOT NULL
      ,  PickZone          NVARCHAR(10)   NOT NULL
      ,  Division          NVARCHAR(30)   NOT NULL
      ,  Material          NVARCHAR(10)   NOT NULL
      ,  SkuCGD            NVARCHAR(18)   NOT NULL
      ,  VAS               INT            NOT NULL
      --,  [Site]            INT            NOT NULL
      ,  CartonGroup       NVARCHAR(10)   NOT NULL   
      ,  CartonID          INT            NOT NULL 
      ,  TotalRatio        FLOAT          NOT NULL DEFAULT(0.00)
      ,  TotalPackCube     FLOAT          NOT NULL DEFAULT(0.00)
      ,  [Status]          NVARCHAR(10)   NOT NULL DEFAULT('0')
     )

   SET @b_success = 1 --Preset to success
   SET @n_StartTCnt=@@TRANCOUNT
   SET @c_PreLottable09 = ''

   WHILE @@TRANCOUNT > 0 
   BEGIN
      COMMIT TRAN
   END

   DECLARE @tORDERS TABLE  
   (  OrderKey          NVARCHAR(10)   NOT NULL
   ,  Loadkey           NVARCHAR(10)   NOT NULL
   ,  Facility          NVARCHAR(5)    NOT NULL
   ,  Storerkey         NVARCHAR(15)   NOT NULL
   ,  CartonGroup       NVARCHAR(20)   NOT NULL
   ,  consigneekey      NVARCHAR(45)   NOT NULL
   ,  ExternOrdKey      NVARCHAR(20)   NOT NULL
   PRIMARY KEY CLUSTERED (OrderKey)
   )

   SET @c_DocumentKey = @c_Wavekey

        IF EXISTS(SELECT 1  
                FROM WAVEDETAIL WD (NOLOCK)
                JOIN ORDERS O (NOLOCK) ON WD.Orderkey = O.Orderkey
                JOIN PACKHEADER PH (NOLOCK) ON O.Orderkey = PH.Orderkey
                JOIN PACKDETAIL PD (NOLOCK) ON PH.Pickslipno = PD.Pickslipno
         WHERE WD.Wavekey = @c_DocumentKey
                AND ISNULL(PH.Orderkey,'') <> '')
         BEGIN
          SELECT @n_continue = 3  
          SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 38010     
          SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': The wave has been pre-cartonized. Not allow to run again. (ispWAVPK06)' --+ ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '           
          GOTO QUIT_SP 
         END

      INSERT INTO @tORDERS
      SELECT DISTINCT WD.Orderkey
                     ,OH.Loadkey
                     ,OH.Facility
                     ,OH.Storerkey
                     ,OD.CartonGroup
                     ,OH.consigneekey
                     ,OH.ExternOrderkey
      FROM WAVEDETAIL WD WITH (NOLOCK)
      JOIN ORDERS     OH WITH (NOLOCK) ON WD.Orderkey = OH.Orderkey
     JOIN ORDERDETAIL OD WITH (NOLOCK) ON OD.Orderkey = OH.Orderkey
      WHERE WD.Wavekey = @c_DocumentKey


       EXEC isp_CreatePickSlip  
               @c_Wavekey = @c_DocumentKey  
              ,@c_ConsolidateByLoad = 'N'  --Y=Create load consolidate pickslip  
              ,@c_LinkPickSlipToPick = 'Y'  --Y=Update pickslipno to pickdetail.pickslipno   
              ,@b_Success = @b_Success OUTPUT  
              ,@n_Err = @n_err OUTPUT   
              ,@c_ErrMsg = @c_errmsg OUTPUT          
            
        IF @b_Success = 0  
        BEGIN
             SELECT @n_continue = 3      
          END  

   SET @c_orderkey = ''

     SET @CUR_PD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
     SELECT 
         PD.Pickdetailkey
        ,T.Orderkey
        ,PD.OrderLineNumber
        ,T.Storerkey
        ,PD.Sku
        ,LOTT.Lottable09
        ,PD.Qty
   FROM @tORDERS T
   JOIN PICKDETAIL PD WITH (NOLOCK) ON T.Orderkey = PD.Orderkey
   JOIN LOC        L  WITH (NOLOCK) ON PD.Loc = L.Loc
   JOIN LOTATTRIBUTE  LOTT WITH (NOLOCK) ON LOTT.Lot=PD.Lot and LOTT.Sku=PD.Sku and LOTT.StorerKey=PD.Storerkey
  -- ORDER BY  T.Orderkey,PD.OrderLineNumber,PD.Sku,LOTT.Lottable09          --CS01
   ORDER BY T.Orderkey,LOTT.Lottable09,PD.OrderLineNumber,PD.Sku             --CS01

   OPEN @CUR_PD

   FETCH NEXT FROM @CUR_PD INTO  @c_PickDetailKey
                              ,  @c_Orderkey
                              ,  @c_OrderLineNumber
                              ,  @c_Storerkey
                              ,  @c_Sku
                              ,  @c_Lottable09
                              ,  @n_Qty

   WHILE @@FETCH_STATUS = 0
   BEGIN
      BEGIN TRAN
   
      --SELECT TOP 1 @c_orderkey = O.orderkey
      ----FROM #tCARTON C
      --FROM @tORDERS O
      --WHERE O.orderkey > @c_orderkey
      --GROUP BY O.orderkey
      --ORDER BY O.orderkey 

      --IF @@ROWCOUNT = 0
      --BEGIN
      --   BREAK
      --END

      SET @c_PickSlipNo = ''
   --  SET @c_Lottable09 = ''

      SELECT @c_PickSlipNo = P.PickHeaderKey 
      FROM PICKHEADER P WITH (NOLOCK) 
      WHERE Orderkey = @c_orderkey

     --SELECT @c_Lottable09 = LOTT.loattable09 
     --FROM @tORDERS T
     --JOIN PICKDETAIL PD WITH (NOLOCK) ON T.Orderkey = PD.Orderkey
   --   JOIN LOTATTRIBUTE  LOTT WITH (NOLOCK) ON LOTT.Lot=PD.Lot and LOTT.Sku=PD.Sku and LOTT.StorerKey=PD.Storerkey
     
      IF @c_PickSlipNo = ''
      BEGIN
         SET @c_Pickslipno = ''  
         EXEC dbo.nspg_GetKey   
               @KeyName     = 'PICKSLIP'
            ,  @fieldlength =  9
            ,  @keystring   = @c_Pickslipno  OUTPUT
            ,  @b_Success   = @b_Success     OUTPUT
            ,  @n_Err       = @n_Err         OUTPUT
            ,  @c_Errmsg    = @c_Errmsg      OUTPUT      
               
         IF @b_success <> 1
         BEGIN
            SET @n_continue = 3  
            SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)
            SET @n_err = 60170   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
            SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Error Executing nspg_GetKey - PICKSLIP. (ispWAVPK06)' 
                           + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '           
            GOTO QUIT_SP
         END
       END   
          
         IF LEFT(@c_Pickslipno,1) <> 'P'
       BEGIN
           SET @c_Pickslipno = 'P' + @c_Pickslipno    
         END          

         BEGIN TRAN 
         IF NOT EXISTS (SELECT 1 FROM PACKHEADER P WITH (NOLOCK) WHERE P.PickSlipNo = @c_PickSlipNo)
         BEGIN 
            INSERT INTO PACKHEADER 
               (
                  PickSlipNo
               ,  Storerkey
               ,  Orderkey
               ,  Loadkey
               ,  consigneekey
               ,  orderrefno 
               ,  CartonGroup
               ,  [Status]
               )
            SELECT TOP 1 @c_PickSlipNo,OH.Storerkey,OH.OrderKey,OH.Loadkey,OH.consigneekey,OH.ExternOrdKey,OH.CartonGroup,'0'
         FROM @tORDERS OH
         WHERE OrderKey =  @c_orderkey

            IF @@ERROR <> 0
            BEGIN
               SET @n_continue = 3  
               SET @n_err = 60200   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
               SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert PACKHEADER fail. (ispWAVPK06)' 
               GOTO QUIT_SP
            END
            SET @n_CartonNo = 0
         END

       IF @c_PreLottable09 <> @c_Lottable09
      BEGIN
          SET @n_CartonNo = @n_CartonNo + 1
        END
        

         IF @b_Debug = 1
         BEGIN
            select  @c_PickSlipNo '@c_PickSlipNo', @n_CartonNo '@n_CartonNo',@c_Lottable09 '@c_Lottable09'
         END

       IF NOT EXISTS (SELECT 1 FROM PACKDETAIL P WITH (NOLOCK) WHERE P.PickSlipNo = @c_PickSlipNo 
                       and p.cartonno = @n_CartonNo and p.sku = @c_Sku and labelno = @c_Lottable09)
         BEGIN 
         INSERT INTO PACKDETAIL
            (  
               PickSlipNo
            ,  CartonNo
            ,  LabelNo
            ,  LabelLine
            ,  Storerkey
            ,  Sku
            ,  Qty 
            ) 
         SELECT 
               @c_PickSlipNo
            ,  @n_CartonNo
            ,  @c_Lottable09
            ,  @c_OrderLineNumber
            ,  @c_Storerkey
            ,  @c_Sku
            ,  @n_Qty
         

         IF @@ERROR <> 0
         BEGIN
            SET @n_continue = 3  
            SET @n_err = 60220   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
            SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert PACKDETAIL fail. (ispWAVPK06)' 
            GOTO QUIT_SP
         END
     END
     ELSE
     BEGIN
         UPDATE PACKDETAIL
         SET Qty = Qty + @n_Qty
         WHERE PickSlipNo = @c_PickSlipNo 
         and cartonno = @n_CartonNo and sku = @c_Sku
         and labelno = @c_Lottable09

       IF @@ERROR <> 0
         BEGIN
            SET @n_continue = 3  
            SET @n_err = 60262   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
            SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update PACKDETAIL fail. (ispWAVPK06)' 
            GOTO QUIT_SP
         END

      END

            UPDATE PICKDETAIL  
               SET CaseID = @c_Lottable09
                  ,Dropid = @c_Lottable09          --CS01
                  ,Trafficcop = NULL
                  ,EditWho = SUSER_NAME()
                  ,EditDate= GETDATE()
            WHERE Pickdetailkey = @c_PickDetailKey

            IF @@ERROR <> 0
            BEGIN
               SET @n_continue = 3  
               SET @n_err = 60260  -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
               SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': UPDATE PICKDETAIL fail. (ispWAVPK06)' 
          
               GOTO QUIT_SP
            END
         --END

       SET @c_PreLottable09 = @c_Lottable09

       FETCH NEXT FROM @CUR_PD INTO  @c_PickDetailKey
                              ,  @c_Orderkey
                              ,  @c_OrderLineNumber
                              ,  @c_Storerkey
                              ,  @c_Sku
                              ,  @c_Lottable09
                              ,  @n_Qty

   END 
   CLOSE @CUR_PD
   DEALLOCATE @CUR_PD

   SET @c_GetPickSlipNo = ''

   SELECT TOP 1 @c_GetPickSlipNo = PH.PickSlipNo
   FROM PACKHEADER PH WITH (NOLOCK)
   JOIN @tORDERS T ON T.Orderkey = PH.Orderkey

      EXEC isp_ScanOutPickSlip    
               @c_PickSlipNo     = @c_GetPickSlipNo  
            ,  @n_err            = @n_err       OUTPUT  
            ,  @c_errmsg         = @c_errmsg    OUTPUT  
  
   IF @n_err <> 0  
   BEGIN  
      SET @n_continue = 3  
      SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+':' + @c_errmsg  
      SET @n_err = 60261   
      SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Executing isp_ScanOutPickSlip. (ispWAVPK06)'   
                    -- + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '   
      GOTO QUIT_SP  
   END 


      WHILE @@TRANCOUNT > 0 
      BEGIN
         COMMIT TRAN
      END
  --END
   -----------------------------------------------------------------------------
   -- CREATE CARTON, CARTONLIST, PICKHEADER, PACKHEADER, PACKDETAIL (END)
   -----------------------------------------------------------------------------
  
QUIT_SP:


   IF OBJECT_ID('tempdb..@tORDERS','u') IS NOT NULL
   DROP TABLE #tPICKDETAIL;

   IF @n_Continue=3  -- Error Occured - Process AND Return
   BEGIN
      SELECT @b_Success = 0
      IF @@TRANCOUNT > 0
      BEGIN
         ROLLBACK TRAN
      END

      EXECUTE dbo.nsp_LogError @n_Err, @c_Errmsg, 'ispWAVPK06'    
      RAISERROR (@c_Errmsg, 16, 1) WITH SETERROR    -- SQL2012    
      
    END
    ELSE
    BEGIN
      SELECT @b_Success = 1
      WHILE @@TRANCOUNT > 0
      BEGIN
         COMMIT TRAN
      END
   END 

    WHILE @@TRANCOUNT < @n_StartTCnt
    BEGIN
      BEGIN TRAN
    END
   
END -- Procedure

GO