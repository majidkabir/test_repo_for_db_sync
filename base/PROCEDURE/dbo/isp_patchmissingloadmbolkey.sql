SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_PatchMissingLoadMbolKey                        */
/* Creation Date: 18-04-2008                                            */
/* Copyright: IDS                                                       */
/* Written by: Shong                                                    */
/*                                                                      */
/* Purpose: Update Missing Loadkey and MbolKey in Order & Order Detail  */
/*                                                                      */
/* Called By: SQL Agent         		                                    */
/*                                                                      */
/* PVCS Version: 1.0		                                                */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* 14-Mar-2012  KHLim01    Update EditDate                              */       
/*                                                                      */
/************************************************************************/
CREATE PROC [dbo].[isp_PatchMissingLoadMbolKey] 
AS
BEGIN
   -- Update Mbolkey in Orderdetail Table 
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
      
   declare @c_mbolkey NVARCHAR(10), @c_loadkey NVARCHAR(10), @c_orderkey NVARCHAR(10), @c_orderlineno NVARCHAR(5)
   
   -- Update MBOLKey in ORDERS Table
   IF exists (select 1 from orders (nolock) 
              JOIN  mboldetail (nolock) ON orders.Orderkey = mboldetail.Orderkey
              JOIN  mbol (nolock) on mbol.mbolkey = mboldetail.mbolkey 
              WHERE mbol.status < '9' 
               and ( orders.mbolkey = '' or orders.mbolkey is null ) )
   Begin 
   	DECLARE Orderdet_Mbol_cur CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
   	select orders.orderkey, mboldetail.mbolkey 
      from orders WITH (nolock) 
              JOIN  mboldetail WITH (nolock) ON orders.Orderkey = mboldetail.Orderkey
              JOIN  mbol WITH (nolock) on mbol.mbolkey = mboldetail.mbolkey 
              WHERE mbol.status < '9' 
                and ( orders.mbolkey = '' or orders.mbolkey is null ) 
   
   	OPEN Orderdet_Mbol_Cur 
   
   	FETCH NEXT FROM Orderdet_Mbol_Cur INTO @c_Orderkey, @c_mbolkey  
   	WHILE @@FETCH_STATUS = 0 
   	BEGIN 
   		Update orders WITH (ROWLOCK) 
            Set Mbolkey = @c_mbolkey, Trafficcop = null 
               ,EditDate = GETDATE() -- KHLim01
         Where orderkey = @c_Orderkey 
           and (mbolkey = '' or mbolkey is null)
   
   		FETCH NEXT FROM Orderdet_Mbol_Cur INTO @c_Orderkey, @c_mbolkey  
   	END
   	CLOSE Orderdet_Mbol_Cur 
   	DEALLOCATE Orderdet_Mbol_Cur 
   End
   Else
   Begin
   	print 'Mbolkey in Orders : No Problem'
   End
   
   -- Update MBOLKey in OrderDetail Table 
   IF exists (select 1 from orderdetail (nolock) 
              JOIN  mboldetail (nolock) ON orderdetail.Orderkey = mboldetail.Orderkey
              JOIN  mbol (nolock) on mbol.mbolkey = mboldetail.mbolkey 
              WHERE mbol.status < '9' 
               and ( orderdetail.mbolkey = '' or orderdetail.mbolkey is null ) )
   Begin 
   	DECLARE Orderdet_Mbol_cur CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
   	select orderdetail.orderkey, orderdetail.Orderlinenumber, mboldetail.mbolkey 
      from orderdetail WITH (nolock) 
              JOIN  mboldetail WITH (nolock) ON orderdetail.Orderkey = mboldetail.Orderkey
              JOIN  mbol WITH (nolock) on mbol.mbolkey = mboldetail.mbolkey 
              WHERE mbol.status < '9' 
                and ( orderdetail.mbolkey = '' or orderdetail.mbolkey is null ) 
   
   	OPEN Orderdet_Mbol_Cur 
   
   	FETCH NEXT FROM Orderdet_Mbol_Cur INTO @c_Orderkey, @c_orderlineno, @c_mbolkey  
   	WHILE @@FETCH_STATUS = 0 
   	BEGIN 
   		Update Orderdetail WITH (ROWLOCK) 
            Set Mbolkey = @c_mbolkey, Trafficcop = null 
               ,EditDate = GETDATE() -- KHLim01
         Where orderkey = @c_Orderkey and Orderlinenumber = @c_orderlineno 
           and (mbolkey = '' or mbolkey is null)
   
   		FETCH NEXT FROM Orderdet_Mbol_Cur INTO @c_Orderkey, @c_orderlineno, @c_mbolkey  
   	END
   	CLOSE Orderdet_Mbol_Cur 
   	DEALLOCATE Orderdet_Mbol_Cur 
   End
   Else
   Begin
   	print 'Mbolkey in Orderdetail : No Problem'
   End
   
   
   -- Update LoadKey in Orders Table 
   IF exists (select 1 from orders (nolock) 
              JOIN  loadplandetail (nolock) ON orders.Orderkey = loadplandetail.Orderkey
              JOIN  loadplan (nolock) on loadplan.loadkey = loadplandetail.loadkey 
              WHERE loadplan.status < '9' 
               and ( orders.loadkey = '' or orders.loadkey is null ) )
   Begin 
   	DECLARE Orderdet_loadplan_cur CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
   	select orders.orderkey, loadplandetail.loadkey 
      from orders WITH (nolock) 
              JOIN  loadplandetail WITH (nolock) ON orders.Orderkey = loadplandetail.Orderkey
              JOIN  loadplan WITH (nolock) on loadplan.loadkey = loadplandetail.loadkey 
              WHERE loadplan.status < '9' 
                and ( orders.loadkey = '' or orders.loadkey is null ) 
   
   	OPEN Orderdet_loadplan_Cur 
   
   	FETCH NEXT FROM Orderdet_loadplan_Cur INTO @c_Orderkey, @c_loadkey  
   	WHILE @@FETCH_STATUS = 0 
   	BEGIN 
   		Update orders WITH (ROWLOCK) 
            Set loadkey = @c_loadkey, Trafficcop = null 
               ,EditDate = GETDATE() -- KHLim01
         Where orderkey = @c_Orderkey 
           and (loadkey = '' or loadkey is null)
   
   		FETCH NEXT FROM Orderdet_loadplan_Cur INTO @c_Orderkey, @c_loadkey  
   	END
   	CLOSE Orderdet_loadplan_Cur 
   	DEALLOCATE Orderdet_loadplan_Cur 
   End
   Else
   Begin
   	print 'LoadKey in Orders : No Problem'
   End
   
   IF exists (select 1 from orderdetail (nolock) 
              JOIN  loadplandetail (nolock) ON orderdetail.Orderkey = loadplandetail.Orderkey
              JOIN  loadplan (nolock) on loadplan.loadkey = loadplandetail.loadkey 
              WHERE loadplan.status < '9' 
               and ( orderdetail.loadkey = '' or orderdetail.loadkey is null ) )
   Begin 
   	DECLARE Orderdet_loadplan_cur CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
   	select orderdetail.orderkey, orderdetail.Orderlinenumber, loadplandetail.loadkey 
      from orderdetail WITH (nolock) 
              JOIN  loadplandetail WITH (nolock) ON orderdetail.Orderkey = loadplandetail.Orderkey
              JOIN  loadplan WITH (nolock) on loadplan.loadkey = loadplandetail.loadkey 
              WHERE loadplan.status < '9' 
                and ( orderdetail.loadkey = '' or orderdetail.loadkey is null ) 
   
   	OPEN Orderdet_loadplan_Cur 
   
   	FETCH NEXT FROM Orderdet_loadplan_Cur INTO @c_Orderkey, @c_orderlineno, @c_loadkey  
   	WHILE @@FETCH_STATUS = 0 
   	BEGIN 
   		Update Orderdetail WITH (ROWLOCK) 
            Set loadkey = @c_loadkey, Trafficcop = null 
               ,EditDate = GETDATE() -- KHLim01
         Where orderkey = @c_Orderkey and Orderlinenumber = @c_orderlineno 
           and (loadkey = '' or loadkey is null)
   
   		FETCH NEXT FROM Orderdet_loadplan_Cur INTO @c_Orderkey, @c_orderlineno, @c_loadkey  
   	END
   	CLOSE Orderdet_loadplan_Cur 
   	DEALLOCATE Orderdet_loadplan_Cur 
   End
   Else
   Begin
   	print 'LoadKey in Orderdetail : No Problem'
   End
End -- Procedure 


GO