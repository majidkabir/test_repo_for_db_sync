SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_PiecePickSlip_size                              */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Pick and Pack Order Creation Print Pickslip                 */
/*                                                                      */
/* Called from:                                                         */
/*                                                                      */
/* Exceed version: 5.4                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 05-Aug-2013 1.0  James       Created                                 */
/************************************************************************/

CREATE PROC [RDT].[rdt_PiecePickSlip_size] (
   @c_LoadKey  NVARCHAR(10))
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  @c_OrderKey      NVARCHAR(10),
            @c_PickHeaderKey NVARCHAR(10),
            @n_err           Int,
            @n_continue      Int,
            @b_success       Int,
            @c_errmsg        NVARCHAR(255),
            @n_StartTranCnt  Int,
            @c_Storerkey     NVARCHAR(15),
            @c_Facility      NVARCHAR(5) 
           
   SELECT @n_StartTranCnt = @@TRANCOUNT, @n_continue = 1

   BEGIN TRAN
   SAVE TRAN NEW_PICKSLIP

   SELECT TOP 1 
      @c_Storerkey = Storerkey,  
      @c_Facility  = Facility  
   FROM ORDERS (NOLOCK)  
   WHERE Loadkey = @c_Loadkey 
   
   DECLARE PickSlip_CUR CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT ORDERS.Orderkey
   FROM   PICKDETAIL PD WITH (NOLOCK)
   JOIN   ORDERS WITH (NOLOCK) ON ORDERS.Orderkey = PD.Orderkey
   WHERE  PD.Status      < '5'
   AND    ORDERS.Loadkey = @c_loadkey
   AND    PD.Qty > 0
   ORDER BY ORDERS.SOStatus DESC

   OPEN PickSlip_CUR
   FETCH NEXT FROM PickSlip_CUR INTO @c_OrderKey

   WHILE (@@FETCH_STATUS <> -1)
   BEGIN
      SELECT @c_PickHeaderKey = ''

      IF NOT EXISTS( SELECT 1 FROM PickHeader WITH (NOLOCK)
                     WHERE ExternOrderKey = @c_LoadKey AND  Orderkey = @c_OrderKey AND  Zone = '3' )
      BEGIN
         BEGIN TRAN
         
         SELECT @b_success = 0
         EXECUTE nspg_GetKey
               'PICKSLIP',
               9,
               @c_PickHeaderKey OUTPUT,
               @b_success       OUTPUT,
               @n_err           OUTPUT,
               @c_errmsg        OUTPUT

         IF @b_success <> 1
         BEGIN
            SELECT @n_continue = 3
            SELECT @n_err = 63500 -- SOS# 245168
            SELECT @c_errmsg = 'NSQL' + CONVERT(Char(5),@n_err) + ': Get PICKSLIP number failed. (nspPiecePickSlip_size)'   
            GOTO RollBackTran         
         END

         IF @n_continue = 1 OR @n_continue = 2
         BEGIN
            SELECT @c_PickHeaderKey = 'P' + @c_PickHeaderKey

            INSERT INTO PICKHEADER (PickHeaderKey,  ExternOrderKey, Orderkey, Zone)
            VALUES (@c_PickHeaderKey, @c_LoadKey, @c_OrderKey, '3')

            SELECT @n_err = @@ERROR

            IF @n_err <> 0
            BEGIN
               SELECT @n_continue = 3
               SELECT @n_err = 63501
               SELECT @c_errmsg = 'NSQL' + CONVERT(Char(5),@n_err) + ': Insert Into PICKHEADER Failed. (nspPiecePickSlip_size)'
	            GOTO RollBackTran
            END
         END -- @n_continue = 1 or @n_continue = 2
      END

      FETCH NEXT FROM PickSlip_CUR INTO @c_OrderKey -- June01
   END -- While
   CLOSE PickSlip_CUR
   DEALLOCATE PickSlip_CUR


   GOTO Quit
   
   RollBackTran:
      ROLLBACK TRAN NEW_PICKSLIP

   Quit:
   WHILE @@TRANCOUNT > @n_StartTranCnt  
      COMMIT TRAN NEW_PICKSLIP 
END /* main procedure */

GO