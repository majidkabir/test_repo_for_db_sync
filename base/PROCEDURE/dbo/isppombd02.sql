SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/**************************************************************************/
/* Stored Procedure: ispPOMBD02                                           */
/* Creation Date:20-Jun-2019                                              */
/* Copyright: IDS                                                         */
/* Written by:CSCHONG                                                     */
/*                                                                        */
/* Purpose:WMS-9332 THA-Automatic Calculate Value TotalCartons Mboldetail */
/*                                                                        */
/* Called By:  POSTAddMBOLDETAILSP                                        */
/*                                                                        */
/* PVCS Version: 1.0                                                      */
/*                                                                        */
/* Version: 5.4                                                           */
/*                                                                        */
/* Data Modifications:                                                    */
/*                                                                        */
/* Updates:                                                               */
/* Date         Author        Purposes                                    */
/* 10-MAY-2019  CSCHONG       WMS-8912-WMS - add new copy field (CS01)    */
/**************************************************************************/
 
CREATE PROCEDURE [dbo].[ispPOMBD02] 
   @c_mbolkey     NVARCHAR( 10), 
   @c_OrderKey    NVARCHAR( 10),  
   @c_loadkey     NVARCHAR( 10), 
   @b_Success     INT           OUTPUT,    
   @n_Err         INT           OUTPUT,    
   @c_ErrMsg      NVARCHAR(250) OUTPUT   
AS
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cStorerKey     NVARCHAR( 15)
   DECLARE @n_cnt          INT
   DECLARE @n_continue     INT

 
   -- Determine Xdock, conso or discrete
   IF @c_OrderKey <> '' AND @c_OrderKey IS NOT NULL
   BEGIN
      -- Get Order company and orderdetail openqty info
      DECLARE @c_Company NVARCHAR(45)
      DECLARE @n_totalctn INT
      
     SET @n_totalctn = 1
      
    IF EXISTS (SELECT 1 FROM ORDERS OH WITH (NOLOCK)
               JOIN PACKHEADER PH WITH (NOLOCK) ON PH.Orderkey = OH.Orderkey
               JOIN PACKDETAIL PD (NOLOCK) ON PD.Pickslipno = PH.Pickslipno
               WHERE OH.Orderkey = @c_OrderKey)
    BEGIN        
      
      SELECT @n_totalctn = COUNT(DISTINCT PD.CartonNo)
      FROM ORDERS OH WITH (NOLOCK)
      JOIN PACKHEADER PH WITH (NOLOCK) ON PH.Orderkey = OH.Orderkey
      JOIN PACKDETAIL PD (NOLOCK) ON PD.Pickslipno = PH.Pickslipno
      WHERE OH.Orderkey = @c_OrderKey
    END
    ELSE
    BEGIN
      
    select @n_totalctn = sum((pd.Qty/nullif(p.CaseCnt,0)))
    from pickdetail pd (nolock)
    join SKU s (nolock) on s.StorerKey = pd.Storerkey and s.Sku = pd.Sku
    join PACK p (nolock) on p.PackKey=s.PACKKey
    where pd.orderkey = @c_OrderKey

    END

   IF ISNULL(@n_totalctn,'0') = '0'
   BEGIN
     SET @n_totalctn = 1
   END 
      
       UPDATE MBOLDETAIL WITH (ROWLOCK) 
         SET    totalCartons = @n_totalctn
                ,TrafficCop = NULL
               ,EditDate = GETDATE() 
         WHERE  MBOLKey = @c_MBOLKey
         AND    Orderkey = @c_OrderKey
   
         SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT 
         IF @n_err <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @n_Err = CONVERT(CHAR(250),@n_err), @n_err=72812   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_ErrMsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed on Table MBOL Detail. (ispPOMBD02)' 
         END
   END

GO