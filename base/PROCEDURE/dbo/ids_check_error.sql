SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: ids_Check_Error                                    */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:                                                             */
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
/* Date         Author   ver  Purposes                                  */
/* 14-09-2009   TLTING   1.1  ID field length	(tlting01)                */
/************************************************************************/

CREATE PROC [dbo].[ids_Check_Error]
   @c_orderkey NVARCHAR(10)
 AS
 BEGIN
   SET NOCOUNT ON 
   SET ANSI_NULLS OFF 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
 	
 select storerkey,sku,lot,id,loc,Orderkey=@c_orderkey
 into #pickerr
 from pickdetail(nolock)
 where pickdetail.orderkey=@c_orderkey
 declare  @c_storerkey NVARCHAR(15)
 ,        @c_sku       NVARCHAR(20)
 ,        @c_lot       NVARCHAR(10)
 ,        @c_id        NVARCHAR(18)			  --tlting01
 ,        @c_loc       NVARCHAR(10)
 ,        @c_ordkey   NVARCHAR(10)
 DECLARE cur_update_pk CURSOR FAST_FORWARD READ_ONLY FOR
 SELECT storerkey,sku,lot,id,loc ,orderkey
 FROM #pickerr (NOLOCK)
   OPEN cur_update_pk
          WHILE (1 = 1)
          BEGIN
          FETCH NEXT FROM cur_update_pk INTO @c_storerkey,@c_sku,@c_lot,@c_id,@c_loc,@c_ordkey
          print @c_sku
          IF @@FETCH_STATUS <> 0 BREAK
             UPDATE pickdetail
             SET status='5'
             WHERE  Storerkey=@c_storerkey
             and   sku =@c_sku
             and   loc=@c_loc
             and   orderkey=@c_orderkey
             and   status<>'9'
         End   -- while      
      close cur_update_pk
 end
    deallocate cur_update_pk
 drop table #pickerr



GO