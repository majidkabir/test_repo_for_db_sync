SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: ispPOMBD01                                         */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Called By:  POSTAddMBOLDETAILSP                                      */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/* 10-MAY-2019  CSCHONG       WMS-8912-WMS - add new copy field (CS01)  */
/************************************************************************/
 
CREATE PROCEDURE [dbo].[ispPOMBD01] 
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
      DECLARE @n_Openqty INT

     DECLARE @n_capacity  FLOAT   --CS01
     DECLARE @n_GrossWgt FLOAT    --CS01
      
      SET @c_Company = ''
      SET @n_Openqty = 0
      SET @n_capacity = 0        --CS01
      SET @n_GrossWgt = 0        --CS01
      
      SELECT TOP 1 @c_Company = C_Company 
      FROM dbo.ORDERS WITH (NOLOCK)
      WHERE ORDERKEY = @c_Orderkey
      
      SELECT @n_Openqty = SUM(OD.Openqty)
      FROM ORDERDETAIL OD WITH (NOLOCK)
      WHERE OD.Orderkey = @c_Orderkey

     --CS01 Start
      
      SELECT 
         @n_capacity = Capacity 
        ,@n_GrossWgt = GrossWeight
      FROM dbo.ORDERS WITH (NOLOCK)
      WHERE ORDERKEY = @c_Orderkey
     AND UserDefine08 = '2'

     --CS01 End
      
       UPDATE MBOLDETAIL WITH (ROWLOCK) 
         SET    [Description] = @c_Company,
                totalCartons = @n_Openqty,
                [cube] = CASE WHEN @n_capacity > 0 THEN @n_capacity ELSE [cube] END,            --CS01
                [weight] = CASE WHEN @n_GrossWgt > 0 THEN @n_GrossWgt ELSE [weight] END,          --CS01
                TrafficCop = NULL
               ,EditDate = GETDATE() 
         WHERE  MBOLKey = @c_MBOLKey
         AND    Orderkey = @c_OrderKey
   
         SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT 
         IF @n_err <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @n_Err = CONVERT(CHAR(250),@n_err), @n_err=72812   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_ErrMsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed on Table MBOL Detail. (ispPOMBD01)' 
         END
      END

GO