import { useForm } from "react-hook-form";
import Swal from "sweetalert2";
import axios from "axios";
import { API_DESPACHOS_URL } from "../../config/api";

export const FormCierreDespacho = ({ despacho, onClose }) => {
  const { register, handleSubmit } = useForm();

  const onSubmit = async (data) => {
    console.log("onSubmit ejecutado");
    
    const jsonData = {
      fechaDespacho: despacho.fechaDespacho,
      patenteCamion: despacho.patenteCamion,
      intento: data.intento,
      despachado: data.despachado,
      idCompra: despacho.idCompra,
      direccionCompra: despacho.direccionCompra,
      valorCompra: despacho.valorCompra,
    };

    console.log("Datos del formulario a enviar:", jsonData);

    try {
      // Usamos template strings para inyectar la URL y el ID
      await axios.put(
        `${API_DESPACHOS_URL}/api/v1/despachos/${despacho.idDespacho}`,
        jsonData,
        {
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json'
          }
        }
      );

      await Swal.fire({
        title: "Despacho modificado 🛻!",
        text: "El despacho ha sido modificado exitosamente",
        icon: "success",
        confirmButtonText: "Aceptar",
      });
      
      // Cerramos el modal solo si la petición fue exitosa
      onClose();

    } catch (error) {
      console.error("Error en la solicitud:", error);
      Swal.fire({
        title: "Error al actualizar",
        text: "No se pudo conectar con el servidor de despachos",
        icon: "error",
        confirmButtonText: "Reintentar",
      });
    }
  };

  return (
    <>
      <form
        onSubmit={handleSubmit(onSubmit)}
        className="flex flex-col justify-center text-center px-24 text-xl"
      >
        <div className="mx-auto text-3xl font-bold mb-10 text-teal-600">
          Editar y cierre de despacho
        </div>
        
        <div className="mb-5">
          <label className="block font-bold mb-2">ID despacho</label>
          <input
            disabled={true}
            type="text"
            className="border border-gray-300 rounded-lg block w-full p-1 text-slate-400 bg-gray-50"
            value={despacho.idDespacho}
          />
        </div>

        <div className="mb-5">
          <label className="block font-bold mb-2">Fecha despacho</label>
          <input
            type="date"
            className="border border-gray-300 rounded-lg block w-full text-slate-400 p-1 bg-gray-50"
            value={despacho.fechaDespacho}
            disabled={true}
          />
        </div>

        <div className="mb-5">
          <label className="block font-bold mb-2">Patente Camión</label>
          <input
            type="text"
            disabled={true}
            value={despacho.patenteCamion}
            className="border border-gray-300 rounded-lg block w-full text-slate-400 p-1 bg-gray-50"
          />
        </div>

        <div className="mb-5">
          <label className="block font-bold mb-2">Intentos de entrega</label>
          <input
            type="number"
            defaultValue={despacho.intento}
            className="border border-gray-300 rounded-lg block w-full p-1 focus:ring-teal-500 focus:border-teal-500"
            {...register("intento", { required: true })}
          />
        </div>

        <div className="mb-5">
          <label className="block font-bold mb-2">Estado del despacho</label>
          <select
            defaultValue={despacho.despachado}
            className="border border-gray-300 rounded-lg block w-full p-1 focus:ring-teal-500 focus:border-teal-500"
            {...register("despachado", { required: true })}
          >
            <option value={false}>Despacho abierto (Pendiente)</option>
            <option value={true}>Cerrar despacho (Entregado)</option>
          </select>
        </div>

        <div className="mb-5">
          <label className="block font-bold mb-2">ID Compra</label>
          <input
            type="text"
            className="border border-gray-300 rounded-lg block w-full text-slate-400 p-1 bg-gray-50"
            disabled={true}
            value={despacho.idCompra}
          />
        </div>

        <div className="mb-5">
          <label className="block font-bold mb-2">Dirección Compra</label>
          <input
            type="text"
            className="border border-gray-300 rounded-lg block w-full text-slate-400 p-1 bg-gray-50"
            disabled={true}
            value={despacho.direccionCompra}
          />
        </div>

        <div className="mb-10">
          <label className="block font-bold mb-2">Valor Compra</label>
          <input
            type="text"
            className="border border-gray-300 rounded-lg block w-full text-slate-400 p-1 bg-gray-50"
            disabled={true}
            value={`$${despacho.valorCompra}`}
          />
        </div>

        <button
          className="py-4 px-14 rounded-lg bg-teal-600 text-white font-bold mb-14 hover:bg-teal-700 transition-colors shadow-lg"
          type="submit"
        >
          Guardar Cambios
        </button>
      </form>
    </>
  );
};
